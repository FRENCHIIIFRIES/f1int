#pragma once

#include <QAbstractListModel>
#include <QColor>
#include <QJsonObject>
#include <QSortFilterProxyModel>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

// The list of open tabs, in tab-bar order. The QML tab bar shows it; the web pages
// themselves live in QML and are only created when a tab is first opened.
// Rules it keeps: pinned tabs come first, and tabs of one group sit next to each other.
class TabModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int currentId READ currentId WRITE setCurrentId NOTIFY currentIdChanged)
    Q_PROPERTY(QVariantList groups READ groups NOTIFY groupsChanged)

public:
    enum Role { IdRole = Qt::UserRole + 1, UrlRole, TitleRole, IconRole, PinnedRole, GroupRole,
                GroupKeyRole, AsleepRole, AudibleRole, MutedRole, LoadingRole };

    explicit TabModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_tabs.size()); }
    int currentId() const { return m_current; }
    void setCurrentId(int id);
    QVariantList groups() const;

    // Opens a tab right after `afterId` (or at the end) and returns its id.
    // A tab opened from a grouped tab joins that group, like in Chrome.
    Q_INVOKABLE int add(const QUrl &url, bool activate = true, int afterId = -1);
    Q_INVOKABLE void close(int id);
    Q_INVOKABLE int reopenClosed();                 // Ctrl+Shift+T
    Q_INVOKABLE void closeOthers(int keepId);       // pinned tabs are kept
    Q_INVOKABLE int duplicate(int id);
    Q_INVOKABLE void move(int id, int beforeOrAtId); // drag and drop: take the place of the other tab
    Q_INVOKABLE void setPinned(int id, bool pinned);
    // Live info from the page: title, url, icon, loading, audible, asleep, muted.
    Q_INVOKABLE void update(int id, const QVariantMap &changes);

    Q_INVOKABLE int idAt(int row) const;
    Q_INVOKABLE int rowOf(int id) const;
    Q_INVOKABLE QVariantMap tab(int id) const;     // all fields of one tab, for QML

    // Session restore: everything needed to bring the tabs back after a restart or crash.
    QJsonObject toJson() const;
    void fromJson(const QJsonObject &session);

    // Groups: named, coloured, collapsible.
    Q_INVOKABLE int addGroup(const QString &name, const QColor &color);
    Q_INVOKABLE void setGroup(int tabId, int groupId);   // -1 = no group
    Q_INVOKABLE void editGroup(int groupId, const QVariantMap &changes);   // name, color, collapsed
    Q_INVOKABLE void ungroup(int groupId);
    Q_INVOKABLE void closeGroup(int groupId);

signals:
    void countChanged();
    void currentIdChanged();
    void groupsChanged();
    void tabClosed(int id);   // QML destroys that tab's page

private:
    struct Tab {
        int id = 0;
        QUrl url;
        QString title;
        QUrl icon;
        bool pinned = false;
        int group = -1;
        bool asleep = false, audible = false, muted = false, loading = false;
    };
    struct Group { int id; QString name; QColor color; bool collapsed = false; };

    int indexOf(int id) const;
    int groupIndex(int groupId) const;
    void moveRow(int from, int to);   // to = final position
    void removeRow(int row);
    void changed(int row, const QList<int> &roles = {});
    void dropEmptyGroups();

    QList<Tab> m_tabs;
    QList<Group> m_groups;
    QList<QUrl> m_closed;   // recently closed, newest last
    int m_current = -1;
    int m_nextId = 1;
};

// Shows part of the tab list: pinned or unpinned tabs, optionally only those whose
// title or address contains `text` (the tab search box).
class TabFilter : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool pinned READ pinned WRITE setPinned NOTIFY changed)
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY changed)

public:
    using QSortFilterProxyModel::QSortFilterProxyModel;
    bool pinned() const { return m_pinned; }
    void setPinned(bool p) { if (p != m_pinned) { m_pinned = p; invalidateRowsFilter(); emit changed(); } }
    QString text() const { return m_text; }
    void setText(const QString &t) { if (t != m_text) { m_text = t; invalidateRowsFilter(); emit changed(); } }

signals:
    void changed();

protected:
    bool filterAcceptsRow(int row, const QModelIndex &parent) const override;

private:
    bool m_pinned = false;
    QString m_text;
};
