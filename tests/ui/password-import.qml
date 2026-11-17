import QtCore
import QtQuick
import f1int

// Importing passwords, in the separate test profile, with made-up logins only:
// welcome card (no vault yet: create it inline, then import) -> panel while locked (unlock
// inline, same file again = nothing new) -> copy an address -> delete the file.
// Not covered: a real drop from Explorer (a script can't make one; the drop zone calls the same take()).
//   tools\ui-test.ps1 tests\ui\password-import.qml -Name f1int-test-agent -Urls "https://www.wikipedia.org"
Item {
    id: test
    property var win
    property int step: 0
    property var welcome: null
    property var imp: null
    // An export in the temp folder with spaces, accents, other scripts and "#" in its name.
    readonly property string file: StandardPaths.writableLocation(StandardPaths.TempLocation) + "/"
                                   + encodeURIComponent("f1int test Pässwörter #1 日本.csv")
    function say(text) { console.warn("SHOT " + text) }
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    function find(item, ok) {
        if (!item) return null
        if (ok(item)) return item
        for (let i = 0; i < item.children.length; ++i) { const f = find(item.children[i], ok); if (f) return f }
        return null
    }
    function importer(root) { return find(root, (o) => o.take !== undefined && o.sources !== undefined) }
    function field(hint) { return find(imp, (o) => o.placeholderText === hint && o.visible) }
    function button(text) { return find(imp, (o) => o.text === text && o.clicked !== undefined && o.visible) }

    TextEdit { id: pasted; visible: false }

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            const v = Browser.passwords
            switch (test.step++) {
            case 0:   // a browser's export: three logins, one with a comma and a quote in the password
                Browser.setSetting("appearance/glass", false)
                test.check(v.setUp("some other master", false), "made a vault to export from")
                v.save("https://mail.test/", "ana@mail.test", "pa,ss\"word-1")
                v.save("https://shop.test/", "ana", "Shop-Pass-22")
                v.save("https://news.test/", "ana", "News-Pass-33")
                test.check(v.exportCsv(test.file), "export written to " + decodeURIComponent(test.file))
                v.forgetVault()
                w.showWelcome = true
                break
            case 1:
                test.welcome = test.find(w.contentItem, (o) => o.steps !== undefined && o.sparkAt !== undefined)
                test.welcome.next()   // page 2: bring your stuff over
                break
            case 2:
                test.imp = test.importer(test.welcome)
                test.check(test.imp !== null, "welcome page has the importer")
                test.say("import-welcome")
                break
            case 3:   // no vault yet: choosing the file asks for a master password instead of doing nothing
                test.imp.take(test.file)
                test.check(v.state === "none" && /master password/.test(test.imp.result), "asks for a master password first: " + test.imp.result)
                test.say("import-welcome-setup")
                break
            case 4:
                test.field("Master password (8+ characters)").text = "test master password"
                test.field("Repeat it").text = "test master pasword"   // a typo
                test.button("Create vault and import").clicked()
                test.check(v.state === "none" && /don't match/.test(test.imp.result), "a mistyped repeat is caught: " + test.imp.result)
                test.field("Repeat it").text = "test master password"
                test.button("Create vault and import").clicked()
                test.check(v.state === "unlocked" && v.entries().length === 3, "vault created and 3 passwords imported")
                test.check(test.imp.result === "Imported 3 passwords.", "result shown: " + test.imp.result)
                break
            case 5: test.say("import-welcome-done"); break
            case 6:
                test.welcome.finish()
                v.lock()
                w.panel = "passwords"
                break
            case 7: test.say("import-panel-locked"); break
            case 8: {
                const panel = test.find(w.contentItem, (o) => o.importing !== undefined && o.revealedId !== undefined)
                panel.importing = true
                test.imp = test.importer(panel)
                const copy = test.find(test.imp, (o) => o.tip === "Copy the address")
                copy.clicked()
                pasted.text = ""; pasted.paste()
                test.check(pasted.text === "chrome://password-manager/settings", "Copy puts the address on the clipboard: " + pasted.text)
                test.imp.take(test.file)   // locked: it asks to unlock, then carries on
                test.check(test.imp.waiting && /unlock/i.test(test.imp.result), "asks to unlock first: " + test.imp.result)
                break
            }
            case 9: test.say("import-panel-unlock"); break
            case 10:
                test.field("Master password").text = "wrong one"
                test.button("Unlock and import").clicked()
                test.check(v.state === "locked" && /not the master password/.test(test.imp.result), "wrong master password said so")
                test.field("Master password").text = "test master password"
                test.button("Unlock and import").clicked()
                test.check(v.entries().length === 3, "the same file again adds nothing (" + v.entries().length + " saved)")
                test.check(test.imp.result === "No new passwords. 3 already saved.", "result shown: " + test.imp.result)
                break
            case 11: test.say("import-panel-again"); break
            case 12:
                test.button("Delete the exported file").clicked()
                test.check(/^Deleted f1int test Pässwörter #1 日本\.csv/.test(test.imp.result), "export deleted: " + test.imp.result)
                test.imp.source = 1   // Edge's steps, for the screenshot
                break
            case 13: test.say("import-panel-deleted"); break
            case 14:
                test.imp.take(test.file)
                test.check(test.imp.problem && /Couldn't open/.test(test.imp.result), "file is gone: " + test.imp.result)
                break
            case 15:
                v.forgetVault()
                console.warn("DONE")
                running = false
                break
            }
        }
    }
}
