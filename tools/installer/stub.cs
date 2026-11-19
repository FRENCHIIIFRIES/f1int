// f1int's installer .exe: this small program with setup.ps1, uninstall.ps1 and the release zip
// appended after it (see tools\make-installer.ps1). It unpacks them to a temp folder and runs setup.ps1.
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

static class Setup
{
    const ulong Magic = 0x31544E4931463146;   // "F1F1INT1": marks the end of the appended files

    [STAThread]
    static int Main()
    {
        string dir = Path.Combine(Path.GetTempPath(), "f1int-setup-" + Guid.NewGuid().ToString("N"));
        try {
            Directory.CreateDirectory(dir);
            using (FileStream f = File.OpenRead(Application.ExecutablePath)) {
                BinaryReader r = new BinaryReader(f);
                f.Seek(-32, SeekOrigin.End);
                long setup = r.ReadInt64(), uninstall = r.ReadInt64(), zip = r.ReadInt64();
                if (r.ReadUInt64() != Magic || setup <= 0 || uninstall <= 0 || zip <= 0 || setup + uninstall + zip > f.Length - 32)
                    throw new InvalidDataException("the installer is damaged; download it again.");
                f.Seek(f.Length - 32 - setup - uninstall - zip, SeekOrigin.Begin);
                Unpack(f, Path.Combine(dir, "setup.ps1"), setup);
                Unpack(f, Path.Combine(dir, "uninstall.ps1"), uninstall);
                Unpack(f, Path.Combine(dir, "f1int.zip"), zip);
            }
            ProcessStartInfo run = new ProcessStartInfo("powershell.exe",
                "-NoProfile -ExecutionPolicy Bypass -File \"" + Path.Combine(dir, "setup.ps1") + "\"");
            run.UseShellExecute = false;
            Process p = Process.Start(run);
            p.WaitForExit();
            return p.ExitCode;
        } catch (Exception e) {
            MessageBox.Show("f1int couldn't be installed: " + e.Message, "f1int", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        } finally {
            try { Directory.Delete(dir, true); } catch { }
        }
    }

    static void Unpack(Stream from, string path, long length)
    {
        using (FileStream to = File.Create(path)) {
            byte[] buffer = new byte[1 << 20];
            while (length > 0) {
                int n = from.Read(buffer, 0, (int)Math.Min(buffer.Length, length));
                if (n <= 0) throw new EndOfStreamException("the installer is cut short; download it again.");
                to.Write(buffer, 0, n);
                length -= n;
            }
        }
    }
}
