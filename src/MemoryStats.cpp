#include "MemoryStats.h"

#include <QCoreApplication>

#if defined(Q_OS_WIN)
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#include <tlhelp32.h>

QHash<qint64, qint64> processTreeMemory()
{
    // 1. Who is whose parent? (a snapshot of all processes)
    QHash<DWORD, DWORD> parentOf;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    PROCESSENTRY32W e{};
    e.dwSize = sizeof e;
    for (BOOL ok = Process32FirstW(snap, &e); ok; ok = Process32NextW(snap, &e))
        parentOf.insert(e.th32ProcessID, e.th32ParentProcessID);
    CloseHandle(snap);

    // 2. Our process, its children, their children...
    QList<DWORD> tree{ GetCurrentProcessId() };
    for (int i = 0; i < tree.size(); ++i)
        for (auto it = parentOf.cbegin(); it != parentOf.cend(); ++it)
            if (it.value() == tree[i] && it.key() != tree[i] && !tree.contains(it.key()))
                tree.append(it.key());

    // 3. Private memory of each.
    QHash<qint64, qint64> out;
    for (DWORD pid : tree) {
        HANDLE p = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
        if (!p)
            continue;
        PROCESS_MEMORY_COUNTERS_EX pmc{};
        if (K32GetProcessMemoryInfo(p, reinterpret_cast<PROCESS_MEMORY_COUNTERS *>(&pmc), sizeof pmc))
            out.insert(pid, qint64(pmc.PrivateUsage));
        CloseHandle(p);
    }
    return out;
}

#elif defined(Q_OS_MACOS)
#include <libproc.h>
#include <unistd.h>

QHash<qint64, qint64> processTreeMemory()
{
    QHash<qint64, qint64> out;
    QList<pid_t> tree{ getpid() };
    for (int i = 0; i < tree.size(); ++i) {
        pid_t kids[512];
        const int n = proc_listchildpids(tree[i], kids, sizeof kids);
        for (int k = 0; k < n && k < 512; ++k)
            if (!tree.contains(kids[k]))
                tree.append(kids[k]);
    }
    for (pid_t pid : tree) {
        rusage_info_v2 ri{};
        if (proc_pid_rusage(pid, RUSAGE_INFO_V2, reinterpret_cast<rusage_info_t *>(&ri)) == 0)
            out.insert(pid, qint64(ri.ri_phys_footprint));   // what Activity Monitor shows as "Memory"
    }
    return out;
}

#else
QHash<qint64, qint64> processTreeMemory()
{
    return {};   // other systems: not supported yet
}
#endif
