#pragma once

#include <QJsonObject>
#include <QStringList>

// Three-way merge for sync. Each synced category is a map (bookmarks by address, settings
// by key, themes by id...). `base` is what both sides had at the last sync; a key missing
// from a side means that side deleted it. Changes from either side are kept; when both
// changed the same key differently, `preferRemote` decides and the key is listed in
// `conflicts` so the user can be told.
namespace SyncMerge {

inline QJsonObject merge(const QJsonObject &base, const QJsonObject &local, const QJsonObject &remote,
                         bool preferRemote, QStringList *conflicts = nullptr)
{
    QJsonObject out;
    QStringList keys = base.keys() + local.keys() + remote.keys();
    keys.removeDuplicates();
    for (const QString &k : keys) {
        const QJsonValue b = base.value(k), l = local.value(k), r = remote.value(k);   // Undefined = absent
        QJsonValue pick;
        if (l == r)
            pick = l;                     // same on both sides (or deleted on both)
        else if (l == b)
            pick = r;                     // only the other computer changed (or deleted) it
        else if (r == b)
            pick = l;                     // only this computer changed it
        else {
            pick = preferRemote ? r : l;  // both changed it: one wins, and we say so
            if (conflicts)
                conflicts->append(k);
        }
        if (!pick.isUndefined())
            out.insert(k, pick);
    }
    return out;
}

} // namespace SyncMerge
