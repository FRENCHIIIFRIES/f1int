#include "TabModel.h"

#include <QJsonArray>
#include <algorithm>

TabModel::TabModel(QObject *parent) : QAbstractListModel(parent) {}

int TabModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : count();
}

QVariant TabModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= count())
        return {};
    const Tab &t = m_tabs[index.row()];
    switch (role) {
    case IdRole: return t.id;
    case UrlRole: return t.url;
    case TitleRole: {
        // Chromium uses the address as the title when a page has none (or hasn't loaded yet).
        // Show the short site name instead: "github.com", or "" (= "New tab") for blank tabs.
        const QString address = t.url.toString();
        if (!t.title.isEmpty() && t.title != address && t.title != QLatin1String("about:blank"))
            return t.title;
        if (t.url.isEmpty() || address == QLatin1String("about:blank"))
            return QString();
        QString host = t.url.host();
        if (host.startsWith(QLatin1String("www.")))
            host = host.mid(4);
        return host.isEmpty() ? address : host;
    }
    case IconRole: return t.icon;
    case PinnedRole: return t.pinned;
    case GroupRole: return t.group;
    case GroupKeyRole: return t.group < 0 ? QString() : QString::number(t.group);   // for ListView sections
    case AsleepRole: return t.asleep;
    case AudibleRole: return t.audible;
    case MutedRole: return t.muted;
    case LoadingRole: return t.loading;
    }
    return {};
}

QHash<int, QByteArray> TabModel::roleNames() const
{
    return { { IdRole, "tabId" }, { UrlRole, "url" }, { TitleRole, "title" }, { IconRole, "icon" },
             { PinnedRole, "pinned" }, { GroupRole, "groupId" }, { GroupKeyRole, "groupKey" },
             { AsleepRole, "asleep" }, { AudibleRole, "audible" }, { MutedRole, "muted" },
             { LoadingRole, "loading" } };
}

void TabModel::setCurrentId(int id)
{
    if (id == m_current || (id != -1 && indexOf(id) < 0))
        return;
    m_current = id;
    emit currentIdChanged();
}

QVariantList TabModel::groups() const
{
    QVariantList list;
    for (const Group &g : m_groups) {
        int n = 0;
        for (const Tab &t : m_tabs)
            n += t.group == g.id;
        list.append(QVariantMap{ { "id", g.id }, { "name", g.name }, { "color", g.color },
                                 { "collapsed", g.collapsed }, { "count", n } });
    }
    return list;
}

int TabModel::add(const QUrl &url, bool activate, int afterId)
{
    Tab t;
    t.id = m_nextId++;
    t.url = url;
    int row = count();
    const int after = indexOf(afterId);
    if (after >= 0) {
        row = after + 1;
        t.group = m_tabs[after].group;
        // Never land inside the pinned block unless opened from a pinned tab's end.
        if (m_tabs[after].pinned) {
            t.group = -1;
            while (row < count() && m_tabs[row].pinned)
                ++row;
        }
    }
    beginInsertRows({}, row, row);
    m_tabs.insert(row, t);
    endInsertRows();
    emit countChanged();
    if (t.group >= 0)
        emit groupsChanged();   // group tab counts
    if (activate || m_current < 0)
        setCurrentId(t.id);
    return t.id;
}

void TabModel::close(int id)
{
    const int row = indexOf(id);
    if (row < 0)
        return;
    m_closed.append(m_tabs[row].url);
    if (m_closed.size() > 25)
        m_closed.removeFirst();
    if (id == m_current) {
        // Like Chrome: go to the tab on the right, or the left one if it was the last.
        const int next = row + 1 < count() ? row + 1 : row - 1;
        m_current = next >= 0 ? m_tabs[next].id : -1;
    }
    removeRow(row);
    emit currentIdChanged();
    emit tabClosed(id);
}

int TabModel::reopenClosed()
{
    if (m_closed.isEmpty())
        return -1;
    return add(m_closed.takeLast(), true);
}

void TabModel::closeOthers(int keepId)
{
    QList<int> ids;
    for (const Tab &t : m_tabs)
        if (t.id != keepId && !t.pinned)
            ids.append(t.id);
    setCurrentId(keepId);
    for (int id : ids)
        close(id);
}

int TabModel::duplicate(int id)
{
    const int row = indexOf(id);
    return row < 0 ? -1 : add(m_tabs[row].url, true, id);
}

void TabModel::move(int id, int targetId)
{
    const int from = indexOf(id), to = indexOf(targetId);
    if (from < 0 || to < 0 || from == to || m_tabs[from].pinned != m_tabs[to].pinned)
        return;   // pinned and unpinned tabs don't mix
    moveRow(from, to);
    // Groups stay in one piece: landing between two tabs of a group joins it; keeping a
    // neighbour from your own group stays in it; anything else leaves the group.
    Tab &t = m_tabs[to];
    const int before = to > 0 ? m_tabs[to - 1].group : -1;
    const int after = to + 1 < count() ? m_tabs[to + 1].group : -1;
    int group = -1;
    if (before >= 0 && before == after)
        group = before;
    else if (t.group >= 0 && (before == t.group || after == t.group))
        group = t.group;
    if (group != t.group) {
        t.group = group;
        changed(to, { GroupRole, GroupKeyRole });
        dropEmptyGroups();
        emit groupsChanged();
    }
}

void TabModel::setPinned(int id, bool pinned)
{
    const int row = indexOf(id);
    if (row < 0 || m_tabs[row].pinned == pinned)
        return;
    int pinnedCount = 0;
    for (const Tab &t : m_tabs)
        pinnedCount += t.pinned;
    m_tabs[row].pinned = pinned;
    m_tabs[row].group = -1;
    changed(row, { PinnedRole, GroupRole, GroupKeyRole });
    // Pinning puts it at the end of the pinned block; unpinning at the start of the rest.
    moveRow(row, pinned ? pinnedCount : pinnedCount - 1);
    dropEmptyGroups();
    emit groupsChanged();
}

void TabModel::update(int id, const QVariantMap &c)
{
    const int row = indexOf(id);
    if (row < 0)
        return;
    Tab &t = m_tabs[row];
    QList<int> roles;
    // Empty values are ignored: a sleeping page reports an empty title, but we keep the old one.
    if (c.contains("title") && !c["title"].toString().isEmpty()) { t.title = c["title"].toString(); roles << TitleRole; }
    if (c.contains("url") && !c["url"].toUrl().isEmpty()) { t.url = c["url"].toUrl(); roles << UrlRole << TitleRole; }
    if (c.contains("icon")) { t.icon = c["icon"].toUrl(); roles << IconRole; }
    if (c.contains("loading")) { t.loading = c["loading"].toBool(); roles << LoadingRole; }
    if (c.contains("audible")) { t.audible = c["audible"].toBool(); roles << AudibleRole; }
    if (c.contains("asleep")) { t.asleep = c["asleep"].toBool(); roles << AsleepRole; }
    if (c.contains("muted")) { t.muted = c["muted"].toBool(); roles << MutedRole; }
    if (!roles.isEmpty())
        changed(row, roles);
}

int TabModel::idAt(int row) const
{
    return row >= 0 && row < count() ? m_tabs[row].id : -1;
}

int TabModel::rowOf(int id) const
{
    return indexOf(id);
}

QVariantMap TabModel::tab(int id) const
{
    const int row = indexOf(id);
    if (row < 0)
        return {};
    QVariantMap m;
    const QHash<int, QByteArray> names = roleNames();
    for (auto it = names.begin(); it != names.end(); ++it)
        m.insert(QString::fromLatin1(it.value()), data(index(row), it.key()));
    return m;
}

QJsonObject TabModel::toJson() const
{
    QJsonArray tabs, groups;
    for (const Tab &t : m_tabs)
        tabs.append(QJsonObject{ { "url", t.url.toString() }, { "title", t.title }, { "icon", t.icon.toString() },
                                 { "pinned", t.pinned }, { "group", t.group }, { "muted", t.muted },
                                 { "current", t.id == m_current } });
    for (const Group &g : m_groups)
        groups.append(QJsonObject{ { "id", g.id }, { "name", g.name }, { "color", g.color.name() },
                                   { "collapsed", g.collapsed } });
    return { { "tabs", tabs }, { "groups", groups } };
}

void TabModel::fromJson(const QJsonObject &session)
{
    beginResetModel();
    m_tabs.clear();
    m_groups.clear();
    for (const QJsonValue &v : session["groups"].toArray()) {
        const QJsonObject g = v.toObject();
        m_groups.append({ g["id"].toInt(), g["name"].toString(), QColor(g["color"].toString()), g["collapsed"].toBool() });
    }
    int current = -1;
    for (const QJsonValue &v : session["tabs"].toArray()) {
        const QJsonObject o = v.toObject();
        Tab t;
        t.id = m_nextId++;
        t.url = QUrl(o["url"].toString());
        t.title = o["title"].toString();
        t.icon = QUrl(o["icon"].toString());
        t.pinned = o["pinned"].toBool();
        t.group = t.pinned || groupIndex(o["group"].toInt(-1)) < 0 ? -1 : o["group"].toInt();
        t.muted = o["muted"].toBool();
        t.asleep = true;   // restored tabs stay asleep (no page, almost no RAM) until clicked
        if (o["current"].toBool())
            current = t.id;
        m_tabs.append(t);
    }
    // Saved files could be edited by hand: re-apply the "pinned first" rule.
    std::stable_sort(m_tabs.begin(), m_tabs.end(), [](const Tab &a, const Tab &b) { return a.pinned > b.pinned; });
    dropEmptyGroups();
    endResetModel();
    emit countChanged();
    emit groupsChanged();
    m_current = -1;
    setCurrentId(current >= 0 ? current : idAt(0));
}

int TabModel::addGroup(const QString &name, const QColor &color)
{
    int id = 1;
    for (const Group &g : m_groups)
        id = qMax(id, g.id + 1);
    m_groups.append({ id, name, color });
    emit groupsChanged();
    return id;
}

void TabModel::setGroup(int tabId, int groupId)
{
    int row = indexOf(tabId);
    if (row < 0 || m_tabs[row].pinned || (groupId >= 0 && groupIndex(groupId) < 0) || m_tabs[row].group == groupId)
        return;
    // Keep groups in one piece. Joining: go right after the new group's last tab.
    // Leaving: step out past the old group's last tab.
    const int target = groupId >= 0 ? groupId : m_tabs[row].group;
    int last = -1;
    for (int i = 0; i < count(); ++i)
        if (i != row && m_tabs[i].group == target)
            last = i;
    m_tabs[row].group = groupId;
    changed(row, { GroupRole, GroupKeyRole });
    if (last > row)
        moveRow(row, last);   // final position: just after `last` (rows below shift up by one)
    else if (last >= 0 && groupId >= 0)
        moveRow(row, last + 1);
    dropEmptyGroups();
    emit groupsChanged();
}

void TabModel::editGroup(int groupId, const QVariantMap &c)
{
    const int i = groupIndex(groupId);
    if (i < 0)
        return;
    if (c.contains("name")) m_groups[i].name = c["name"].toString();
    if (c.contains("color")) m_groups[i].color = c["color"].value<QColor>();
    if (c.contains("collapsed")) m_groups[i].collapsed = c["collapsed"].toBool();
    emit groupsChanged();
}

void TabModel::ungroup(int groupId)
{
    for (int row = 0; row < count(); ++row)
        if (m_tabs[row].group == groupId) {
            m_tabs[row].group = -1;
            changed(row, { GroupRole, GroupKeyRole });
        }
    dropEmptyGroups();
    emit groupsChanged();
}

void TabModel::closeGroup(int groupId)
{
    QList<int> ids;
    for (const Tab &t : m_tabs)
        if (t.group == groupId)
            ids.append(t.id);
    for (int id : ids)
        close(id);
    dropEmptyGroups();
    emit groupsChanged();
}

int TabModel::indexOf(int id) const
{
    for (int i = 0; i < count(); ++i)
        if (m_tabs[i].id == id)
            return i;
    return -1;
}

int TabModel::groupIndex(int groupId) const
{
    for (int i = 0; i < m_groups.size(); ++i)
        if (m_groups[i].id == groupId)
            return i;
    return -1;
}

void TabModel::moveRow(int from, int to)
{
    if (from == to)
        return;
    // Qt's beginMoveRows wants the destination *before* removal, hence the +1 when moving down.
    beginMoveRows({}, from, from, {}, to > from ? to + 1 : to);
    m_tabs.move(from, to);
    endMoveRows();
}

void TabModel::removeRow(int row)
{
    const bool grouped = m_tabs[row].group >= 0;
    beginRemoveRows({}, row, row);
    m_tabs.removeAt(row);
    endRemoveRows();
    emit countChanged();
    if (grouped) {
        dropEmptyGroups();
        emit groupsChanged();
    }
}

void TabModel::changed(int row, const QList<int> &roles)
{
    emit dataChanged(index(row), index(row), roles);
}

void TabModel::dropEmptyGroups()
{
    m_groups.removeIf([this](const Group &g) {
        for (const Tab &t : m_tabs)
            if (t.group == g.id)
                return false;
        return true;
    });
}

bool TabFilter::filterAcceptsRow(int row, const QModelIndex &parent) const
{
    const QModelIndex i = sourceModel()->index(row, 0, parent);
    if (i.data(TabModel::PinnedRole).toBool() != m_pinned)
        return false;
    return m_text.isEmpty() || i.data(TabModel::TitleRole).toString().contains(m_text, Qt::CaseInsensitive)
           || i.data(TabModel::UrlRole).toUrl().toString().contains(m_text, Qt::CaseInsensitive);
}
