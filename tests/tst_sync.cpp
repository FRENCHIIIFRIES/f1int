// Tests for the sync merge (src/SyncMerge.h).
#include <QtTest>
#include "SyncMerge.h"

class TestSync : public QObject
{
    Q_OBJECT
private slots:
    void keepsBothSidesChanges()
    {
        const QJsonObject base{ { "a", 1 }, { "b", 2 } };
        const QJsonObject local{ { "a", 1 }, { "b", 2 }, { "mine", 3 } };          // added here
        const QJsonObject remote{ { "a", 10 }, { "b", 2 }, { "theirs", 4 } };      // changed + added there
        QStringList conflicts;
        const QJsonObject m = SyncMerge::merge(base, local, remote, true, &conflicts);
        QCOMPARE(m, (QJsonObject{ { "a", 10 }, { "b", 2 }, { "mine", 3 }, { "theirs", 4 } }));
        QVERIFY(conflicts.isEmpty());
    }
    void deletionsTravel()
    {
        const QJsonObject base{ { "a", 1 }, { "b", 2 } };
        const QJsonObject local{ { "b", 2 } };            // "a" deleted here
        const QJsonObject remote{ { "a", 1 } };           // "b" deleted there
        QCOMPARE(SyncMerge::merge(base, local, remote, true), QJsonObject());
    }
    void firstSyncIsAUnion()
    {
        const QJsonObject local{ { "a", 1 }, { "same", 5 } };
        const QJsonObject remote{ { "b", 2 }, { "same", 5 } };
        QCOMPARE(SyncMerge::merge({}, local, remote, true), (QJsonObject{ { "a", 1 }, { "b", 2 }, { "same", 5 } }));
    }
    void conflictsArePickedAndReported()
    {
        const QJsonObject base{ { "theme", "dark" } };
        QStringList conflicts;
        QCOMPARE(SyncMerge::merge(base, { { "theme", "light" } }, { { "theme", "system" } }, true, &conflicts)["theme"].toString(), QString("system"));
        QCOMPARE(SyncMerge::merge(base, { { "theme", "light" } }, { { "theme", "system" } }, false)["theme"].toString(), QString("light"));
        QCOMPARE(conflicts, QStringList{ "theme" });
        // Changed on one side, deleted on the other: a conflict too (the change isn't lost silently).
        conflicts.clear();
        QCOMPARE(SyncMerge::merge(base, { { "theme", "light" } }, {}, false, &conflicts)["theme"].toString(), QString("light"));
        QCOMPARE(conflicts.size(), 1);
    }
};

QTEST_GUILESS_MAIN(TestSync)
#include "tst_sync.moc"
