// Checks the tab list rules: closing picks the right neighbour, pinned tabs stay first,
// groups stay in one piece.
#include <QtTest>
#include "TabModel.h"

class TestTabModel : public QObject
{
    Q_OBJECT

    // Tab ids in tab-bar order, e.g. "1 2 3".
    static QString order(const TabModel &m)
    {
        QStringList ids;
        for (int r = 0; r < m.count(); ++r)
            ids << QString::number(m.idAt(r));
        return ids.join(' ');
    }
    static int group(const TabModel &m, int id) { return m.tab(id)["groupId"].toInt(); }

private slots:
    void addAndClose()
    {
        TabModel m;
        const int a = m.add(QUrl("https://a.test")), b = m.add(QUrl("https://b.test")), c = m.add(QUrl("https://c.test"));
        QCOMPARE(m.currentId(), c);
        m.setCurrentId(b);
        m.close(b);                      // closing the current tab moves to the right neighbour
        QCOMPARE(m.currentId(), c);
        m.close(c);                      // ...or to the left one if it was last
        QCOMPARE(m.currentId(), a);
        QCOMPARE(m.reopenClosed(), 4);   // reopens c's address as a new tab
        QCOMPARE(m.tab(4)["url"].toUrl(), QUrl("https://c.test"));
    }

    void openAfter()
    {
        TabModel m;
        const int a = m.add({}), b = m.add({});
        const int c = m.add({}, false, a);   // opened from a: goes right after it
        QCOMPARE(order(m), QString("%1 %2 %3").arg(a).arg(c).arg(b));
        QCOMPARE(m.currentId(), b);          // background tab didn't take focus
    }

    void pinning()
    {
        TabModel m;
        const int a = m.add({}), b = m.add({}), c = m.add({});
        m.setPinned(c, true);
        QCOMPARE(order(m), QString("%1 %2 %3").arg(c).arg(a).arg(b));
        m.move(a, c);                        // unpinned can't move into the pinned area
        QCOMPARE(order(m), QString("%1 %2 %3").arg(c).arg(a).arg(b));
        m.setPinned(c, false);               // back to the start of the unpinned tabs
        QCOMPARE(order(m), QString("%1 %2 %3").arg(c).arg(a).arg(b));
        QVERIFY(!m.tab(c)["pinned"].toBool());
    }

    void groupsStayTogether()
    {
        TabModel m;
        const int a = m.add({}), b = m.add({}), c = m.add({}), d = m.add({});
        const int g = m.addGroup("Work", Qt::red);
        m.setGroup(a, g);
        m.setGroup(c, g);                    // joins right after a
        QCOMPARE(order(m), QString("%1 %2 %3 %4").arg(a).arg(c).arg(b).arg(d));
        const int e = m.add({}, true, c);    // opened from a grouped tab: joins the group
        QCOMPARE(group(m, e), g);
        m.setGroup(a, -1);                   // leaving steps out past the group's end
        QCOMPARE(order(m), QString("%1 %2 %3 %4 %5").arg(c).arg(e).arg(a).arg(b).arg(d));
        m.move(d, e);                        // dropped between c and e: joins the group
        QCOMPARE(order(m), QString("%1 %2 %3 %4 %5").arg(c).arg(d).arg(e).arg(a).arg(b));
        QCOMPARE(group(m, d), g);
        m.move(d, b);                        // dragged out of the group
        QCOMPARE(group(m, d), -1);
        m.closeGroup(g);                     // closes c and e
        QCOMPARE(order(m), QString("%1 %2 %3").arg(a).arg(b).arg(d));
        QVERIFY(m.groups().isEmpty());       // empty groups disappear
    }

    void closeOthersKeepsPinned()
    {
        TabModel m;
        const int a = m.add({}), b = m.add({}), c = m.add({});
        m.setPinned(a, true);
        m.closeOthers(b);
        QCOMPARE(order(m), QString("%1 %2").arg(a).arg(b));
        Q_UNUSED(c);
    }

    void sessionRoundTrip()
    {
        TabModel m;
        const int a = m.add(QUrl("https://a.test")), b = m.add(QUrl("https://b.test")), c = m.add(QUrl("https://c.test"));
        m.update(b, { { "title", "Bee" } });
        m.setPinned(c, true);
        m.setGroup(b, m.addGroup("Work", Qt::red));
        m.setCurrentId(b);
        Q_UNUSED(a);

        TabModel restored;
        restored.fromJson(m.toJson());
        QCOMPARE(restored.count(), 3);
        const QVariantMap first = restored.tab(restored.idAt(0));
        QCOMPARE(first["url"].toUrl(), QUrl("https://c.test"));      // pinned stays first
        QVERIFY(first["pinned"].toBool());
        const QVariantMap cur = restored.tab(restored.currentId());
        QCOMPARE(cur["title"].toString(), QString("Bee"));           // the open tab is remembered
        QCOMPARE(restored.groups().size(), 1);
        QCOMPARE(cur["groupId"].toInt(), restored.groups()[0].toMap()["id"].toInt());
        QVERIFY(cur["asleep"].toBool());                              // restored tabs start asleep
    }

    void searchFilter()
    {
        TabModel m;
        const int a = m.add(QUrl("https://news.test"));
        m.update(a, { { "title", "Morning News" } });
        m.add(QUrl("https://mail.test"));
        TabFilter f;
        f.setSourceModel(&m);
        QCOMPARE(f.rowCount(), 2);
        f.setText("news");
        QCOMPARE(f.rowCount(), 1);
        f.setPinned(true);
        QCOMPARE(f.rowCount(), 0);
    }
};

QTEST_APPLESS_MAIN(TestTabModel)
#include "tst_tabmodel.moc"
