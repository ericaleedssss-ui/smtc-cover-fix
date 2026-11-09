#pragma once
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#ifdef Q_OS_WIN
#include <qt_windows.h>
#include <psapi.h>
#endif

// Opt-in allocation checkpoints; no sampling or file access on normal launches.
inline void startupMemory(const char *stage) {
    const auto output = qEnvironmentVariable("RHINE_QA_STARTUP_MEMORY");
    if (output.isEmpty()) return;
#ifdef Q_OS_WIN
    PROCESS_MEMORY_COUNTERS_EX counters{};
    counters.cb = sizeof(counters);
    if (!GetProcessMemoryInfo(GetCurrentProcess(),
                             reinterpret_cast<PROCESS_MEMORY_COUNTERS *>(&counters), sizeof(counters))) return;
    SIZE_T largest = 0;
    quintptr largestBase = 0;
    MEMORY_BASIC_INFORMATION region{};
    for (quintptr address = 0; VirtualQuery(reinterpret_cast<void *>(address), &region, sizeof(region));) {
        if (region.State == MEM_COMMIT && region.Type == MEM_PRIVATE && region.RegionSize > largest) {
            largest = region.RegionSize;
            largestBase = reinterpret_cast<quintptr>(region.BaseAddress);
        }
        const auto next = reinterpret_cast<quintptr>(region.BaseAddress) + region.RegionSize;
        if (next <= address) break;
        address = next;
    }
    QFile file(output);
    if (file.open(QIODevice::WriteOnly | QIODevice::Append)) {
        file.write(QJsonDocument(QJsonObject{{"stage", QString::fromLatin1(stage)},
            {"working_set_bytes", double(counters.WorkingSetSize)},
            {"private_commit_bytes", double(counters.PrivateUsage)},
            {"largest_private_region_bytes", double(largest)},
            {"largest_private_region_base", QString::number(largestBase, 16)}}).toJson(QJsonDocument::Compact));
        file.write("\n");
    }
#endif
}
inline QString startupMemoryValue(const char *stage, const QString &value) {
    startupMemory(stage);
    return value;
}
