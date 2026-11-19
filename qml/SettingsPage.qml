import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import f1int

// Settings as a full page over the page area: categories on the left, a search that looks
// through every setting, the chosen category on the right. Changes apply straight away.
Rectangle {
    id: page
    property string category: "general"
    signal closeRequested()
    signal openPanel(string name)          // passwords, customise, ...
    signal welcomeRequested()
    signal newTabPageRequested()
    signal openUrl(url url)

    function get(key, fallback) { void Browser.settingsRevision; return Browser.setting(key, fallback) }
    function set(key, value) { Browser.setSetting(key, value) }

    readonly property var categories: [
        { id: "general", icon: "home", label: qsTr("General") },
        { id: "account", icon: "user", label: qsTr("Account and sync") },
        { id: "appearance", icon: "edit", label: qsTr("Appearance") },
        { id: "sidebar", icon: "sidebar", label: qsTr("Sidebar") },
        { id: "tabs", icon: "window", label: qsTr("Tabs and memory") },
        { id: "newtab", icon: "plus", label: qsTr("New tab page") },
        { id: "passwords", icon: "key", label: qsTr("Passwords") },
        { id: "privacy", icon: "shield", label: qsTr("Privacy and security") },
        { id: "data", icon: "folder", label: qsTr("Import and backup") },
        { id: "downloads", icon: "download", label: qsTr("Downloads") },
        { id: "extensions", icon: "bolt", label: qsTr("Extensions") },
        { id: "advanced", icon: "settings", label: qsTr("Advanced") }]

    color: Theme.bg
    Keys.onEscapePressed: closeRequested()
    Component.onDestruction: Theme.settingsFilter = ""
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = false }   // nothing reaches the page below

    // ---------- categories ----------
    Rectangle {
        id: nav
        width: 240
        height: parent.height
        color: Theme.frame
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 4
            Text {
                text: qsTr("Settings")
                color: Theme.fg
                font.pixelSize: Theme.px(22)
                font.weight: Font.DemiBold
                Layout.leftMargin: 6
                Layout.topMargin: 8
                Layout.bottomMargin: 10
            }
            Ui.Field {
                id: searchField
                Layout.fillWidth: true
                leftPadding: 32
                placeholderText: qsTr("Search settings")
                onTextChanged: Theme.settingsFilter = text.trim().toLowerCase()
                Keys.onEscapePressed: text === "" ? page.closeRequested() : text = ""
                Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; glyph: "search"; sourceSize: Qt.size(14, 14); color: Theme.dim }
                Component.onCompleted: forceActiveFocus()
            }
            Item { Layout.preferredHeight: 6 }
            Repeater {
                model: page.categories
                Rectangle {
                    required property var modelData
                    readonly property bool on: page.category === modelData.id && searchField.text === ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Theme.radius
                    color: on ? Theme.tab : navHover.hovered && Theme.hoverEffects ? Theme.hover : "transparent"
                    border.width: on ? 1 : 0
                    border.color: Theme.line
                    Behavior on color { ColorAnimation { duration: Theme.anim } }
                    HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.label
                    Accessible.selected: on
                    Rectangle {   // the open category gets a short accent bar
                        visible: parent.on
                        width: 3; height: 16; radius: 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.accent
                    }
                    Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; glyph: parent.modelData.icon; color: parent.on ? Theme.fg : Theme.dim }
                    Text {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.label
                        color: Theme.fg
                        font.pixelSize: Theme.px(13)
                        font.weight: parent.on ? Font.Medium : Font.Normal
                    }
                    MouseArea { anchors.fill: parent; onClicked: { searchField.text = ""; page.category = parent.modelData.id; scroller.contentY = 0 } }
                }
            }
            Item { Layout.fillHeight: true }
            Row {
                Layout.leftMargin: 6
                spacing: 8
                Image { source: "qrc:/logo/f1int.svg"; sourceSize: Qt.size(32, 32); width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "f1int " + Browser.version; color: Theme.dim; font.family: Theme.numberFont; font.pixelSize: Theme.px(13); anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ---------- Passwords: the password manager itself, full height ----------
    Rectangle {
        anchors.left: nav.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: page.category === "passwords" && Theme.settingsFilter === ""
        z: 1
        color: Theme.bg
        Loader {   // a readable column, like the other settings
            width: Math.min(780, parent.width - 48)
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            active: parent.visible
            sourceComponent: PasswordsPanel { embedded: true; color: Theme.bg; onCloseRequested: page.closeRequested() }
        }
    }

    // ---------- the chosen category (or every match while searching) ----------
    Flickable {
        id: scroller
        anchors.left: nav.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        contentHeight: column.implicitHeight + 80
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { width: 6 }

        ColumnLayout {
            id: column
            x: Math.max(24, (scroller.width - width) / 2)
            y: 36
            width: Math.min(760, scroller.width - 48)
            spacing: 26
            Repeater {
                model: page.categories
                ColumnLayout {
                    required property var modelData
                    visible: searchField.text !== "" || page.category === modelData.id
                    Layout.fillWidth: true
                    spacing: 18
                    Text {
                        text: parent.modelData.label
                        color: Theme.fg
                        font.family: Theme.headingFamily
                        font.pixelSize: Theme.px(26)
                        font.weight: Font.DemiBold
                        visible: searchField.text === ""
                    }
                    Loader {
                        Layout.fillWidth: true
                        active: parent.visible
                        sourceComponent: ({ general: general, account: accountPage, appearance: appearance, sidebar: sidebarPage, tabs: tabsPage, newtab: newtabPage,
                                            privacy: privacy, data: dataPage, downloads: downloadsPage, extensions: extensionsPage,
                                            advanced: advanced })[parent.modelData.id]
                    }
                }
            }
            Text {
                visible: searchField.text !== "" && column.childrenRect.height < 40
                text: qsTr("No settings match \"%1\"").arg(searchField.text)
                color: Theme.dim
                font.pixelSize: Theme.px(14)
            }
        }
    }
    IconButton {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        iconName: "close"
        tip: qsTr("Close settings (Esc)")
        onClicked: page.closeRequested()
    }

    // ---------- categories ----------
    Component {
        id: general
        ColumnLayout {
            spacing: 22
            Ui.Section {
                title: qsTr("Profiles")
                Repeater {
                    model: Browser.profiles.list
                    Ui.SettingRow {
                        id: profileRow
                        required property var modelData
                        label: modelData.name
                        hint: modelData.current ? qsTr("This window") : qsTr("Separate bookmarks, history, passwords and settings")
                        Row {
                            spacing: 8
                            Ui.Avatar { width: 30; height: 30; name: profileRow.modelData.name; picture: profileRow.modelData.picture; anchors.verticalCenter: parent.verticalCenter }
                            Ui.Field {
                                width: 150
                                text: profileRow.modelData.name
                                maximumLength: 40
                                onEditingFinished: Browser.profiles.rename(profileRow.modelData.id, text)
                                Accessible.name: qsTr("Profile name")
                            }
                            Ui.Pill { text: qsTr("Picture…"); onClicked: { pictureDialog.profileId = profileRow.modelData.id; pictureDialog.open() } }
                            Ui.Pill { visible: !profileRow.modelData.current; text: qsTr("Open"); onClicked: Browser.profiles.open(profileRow.modelData.id) }
                            IconButton {
                                visible: !profileRow.modelData.current && profileRow.modelData.id !== ""
                                iconName: "trash"
                                iconColor: Theme.dim
                                tip: qsTr("Delete this profile")
                                onClicked: { deleteProfile.target = profileRow.modelData; deleteProfile.open() }
                            }
                        }
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Add a profile")
                    hint: profileMessage.text !== "" ? profileMessage.text : qsTr("For another person, or to keep work and home apart. Opens in its own window.")
                    last: true
                    Text { id: profileMessage; visible: false }
                    Ui.Pill { primary: true; text: qsTr("Add profile"); onClicked: Browser.profiles.open(Browser.profiles.add("")) }
                }
            }
            FileDialog {
                id: pictureDialog
                property string profileId: ""
                nameFilters: [qsTr("Pictures (*.png *.jpg *.jpeg *.webp *.bmp *.gif)")]
                onAccepted: if (!Browser.profiles.setPicture(profileId, selectedFile)) profileMessage.text = qsTr("That picture couldn't be read.")
            }
            Popup {
                id: deleteProfile
                property var target: null
                anchors.centerIn: Overlay.overlay
                modal: true
                padding: 20
                width: 380
                background: Rectangle { color: Theme.surface; radius: Theme.cardRadius; border.width: 1; border.color: Theme.line }
                contentItem: Column {
                    spacing: 12
                    Text { text: deleteProfile.target ? qsTr("Delete %1?").arg(deleteProfile.target.name) : ""; color: Theme.fg; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: qsTr("Its bookmarks, history, saved passwords, settings and website logins are deleted from this computer. This can't be undone.")
                        color: Theme.dim
                        font.pixelSize: Theme.px(13)
                    }
                    Row {
                        spacing: 8
                        Ui.Pill {
                            primary: true
                            text: qsTr("Delete profile")
                            onClicked: { profileMessage.text = Browser.profiles.remove(deleteProfile.target.id); deleteProfile.close() }
                        }
                        Ui.Pill { text: qsTr("Cancel"); onClicked: deleteProfile.close() }
                    }
                }
            }
            Ui.Section {
                title: qsTr("Search and home")
                Ui.SettingRow {
                    label: qsTr("Search engine")
                    hint: qsTr("Used when you type words in the address bar")
                    Ui.Segmented {
                        options: Browser.searchEngines.slice(0, 4).map(e => ({ label: e.name, value: e.template }))
                        value: page.get("search/template", "https://www.google.com/search?q=%s")
                        onPicked: (v) => page.set("search/template", v)
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Other search engines")
                    Ui.Segmented {
                        options: Browser.searchEngines.slice(4).map(e => ({ label: e.name, value: e.template }))
                        value: page.get("search/template", "https://www.google.com/search?q=%s")
                        onPicked: (v) => page.set("search/template", v)
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Home page")
                    Ui.Field {
                        width: 240
                        text: page.get("home/url", "https://www.google.com")
                        onEditingFinished: { const url = Browser.urlFromInput(text); if (url.toString() !== "") page.set("home/url", url) }
                    }
                }
                Ui.SettingRow {
                    label: qsTr("New tabs open")
                    last: page.get("newtab/mode", "home") !== "custom"
                    Ui.Segmented {
                        options: [{ label: qsTr("Home page"), value: "home" }, { label: qsTr("f1int page"), value: "f1int" },
                                  { label: qsTr("Blank"), value: "blank" }, { label: qsTr("Address"), value: "custom" }]
                        value: page.get("newtab/mode", "home")
                        onPicked: (v) => page.set("newtab/mode", v)
                    }
                }
                Ui.SettingRow {
                    visible: page.get("newtab/mode", "home") === "custom"
                    label: qsTr("New tab address")
                    last: true
                    Ui.Field { width: 240; text: page.get("newtab/url", ""); placeholderText: "example.com"; onEditingFinished: page.set("newtab/url", text.trim()) }
                }
            }
            Ui.Section {
                visible: Qt.platform.os === "windows"
                title: qsTr("Default browser")
                Ui.SettingRow {
                    label: Browser.isDefaultBrowser() ? qsTr("f1int is your default browser") : qsTr("f1int isn't your default browser")
                    hint: qsTr("Links from other apps, web pages and PDFs open in your default browser")
                    last: true
                    Ui.Pill { visible: !Browser.isDefaultBrowser(); primary: true; text: qsTr("Make default"); onClicked: Browser.makeDefaultBrowser() }
                }
            }
            Ui.Section {
                title: qsTr("Starting up")
                Ui.SettingRow {
                    label: qsTr("Reopen your tabs")
                    hint: qsTr("Also after a crash. Only the open tab loads; the rest wait asleep.")
                    last: true
                    Ui.Toggle { checked: page.get("startup/restore", true); onToggled: page.set("startup/restore", checked) }
                }
            }
        }
    }
    Component { id: appearance; ThemeStudio {} }
    Component { id: accountPage; AccountPage {} }
    Component {
        id: sidebarPage
        ColumnLayout {
            spacing: 22
            Ui.Section {
                title: qsTr("Layout")
                Ui.SettingRow {
                    label: qsTr("Tab column")
                    Ui.Segmented {
                        options: [{ label: qsTr("Left"), value: "left" }, { label: qsTr("Right"), value: "right" }]
                        value: page.get("layout/tabsSide", "left")
                        onPicked: (v) => page.set("layout/tabsSide", v)
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Address bar")
                    Ui.Segmented {
                        options: [{ label: qsTr("Above the page"), value: "page" }, { label: qsTr("Across the window"), value: "window" }, { label: qsTr("In the tab column"), value: "sidebar" }]
                        value: Theme.addressPlace
                        onPicked: (v) => page.set("layout/address", v)
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Width")
                    Ui.Slide { width: 160; from: 200; to: 440; value: Number(page.get("tabbar/width", 260)); onMoved: page.set("tabbar/width", Math.round(value)) }
                }
                Ui.SettingRow {
                    label: qsTr("Depth")
                    hint: qsTr("How much darker than the window it is")
                    last: true
                    Ui.Slide { width: 160; from: -1; to: 1; value: Theme.sidebarDepth; onMoved: page.set("sidebar/depth", Math.round(value * 10) / 10) }
                }
            }
            Ui.Section {
                title: qsTr("What it shows")
                Ui.SettingRow { label: qsTr("Pinned sites"); Ui.Toggle { checked: Theme.showPinned; onToggled: page.set("sidebar/pinned", checked) } }
                Ui.SettingRow { label: qsTr("New tab button"); Ui.Toggle { checked: Theme.showNewTabRow; onToggled: page.set("sidebar/newTabRow", checked) } }
                Ui.SettingRow { label: qsTr("Number of tabs"); hint: qsTr("In the tab search box"); Ui.Toggle { checked: Theme.showTabCount; onToggled: page.set("layout/showTabCount", checked) } }
                Ui.SettingRow { label: qsTr("Memory use"); last: true; Ui.Toggle { checked: Theme.showRam; onToggled: page.set("layout/showRam", checked) } }
            }
            Ui.Section {
                title: qsTr("Shortcuts at the bottom")
                Ui.SettingRow {
                    label: qsTr("Labels")
                    hint: qsTr("Show names next to the icons")
                    Ui.Toggle { checked: Theme.sidebarLabels; onToggled: page.set("sidebar/labels", checked) }
                }
                Ui.SettingRow {
                    label: qsTr("Icon size")
                    Ui.Segmented {
                        options: [{ label: qsTr("Small"), value: 14 }, { label: qsTr("Medium"), value: 16 }, { label: qsTr("Large"), value: 20 }]
                        value: Theme.iconSize
                        onPicked: (v) => page.set("sidebar/iconSize", v)
                    }
                }
                // One row per shortcut: show or hide it, move it up or down.
                Repeater {
                    model: Theme.allShortcuts
                    Ui.SettingRow {
                        id: shortcutRow
                        required property string modelData
                        readonly property int at: Theme.shortcuts.indexOf(modelData)
                        function store(list) { page.set("sidebar/shortcuts", JSON.stringify(list)) }
                        label: ({ bookmarks: qsTr("Bookmarks"), history: qsTr("History"), downloads: qsTr("Downloads"), passwords: qsTr("Passwords"),
                                  search: qsTr("Search tabs"), settings: qsTr("Settings") })[modelData]
                        last: modelData === "settings"
                        Row {
                            spacing: 4
                            IconButton {
                                enabled: shortcutRow.at > 0
                                iconName: "up"; iconSize: 14; tip: qsTr("Move up")
                                onClicked: { const l = Theme.shortcuts.slice(); l.splice(shortcutRow.at, 1); l.splice(shortcutRow.at - 1, 0, shortcutRow.modelData); shortcutRow.store(l) }
                            }
                            IconButton {
                                enabled: shortcutRow.at >= 0 && shortcutRow.at < Theme.shortcuts.length - 1
                                iconName: "down"; iconSize: 14; tip: qsTr("Move down")
                                onClicked: { const l = Theme.shortcuts.slice(); l.splice(shortcutRow.at, 1); l.splice(shortcutRow.at + 1, 0, shortcutRow.modelData); shortcutRow.store(l) }
                            }
                            Ui.Toggle {
                                checked: shortcutRow.at >= 0
                                onToggled: shortcutRow.store(checked ? Theme.shortcuts.concat([shortcutRow.modelData]) : Theme.shortcuts.filter(s => s !== shortcutRow.modelData))
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: tabsPage
        ColumnLayout {
            spacing: 22
            Ui.Section {
                title: qsTr("Tabs")
                Ui.SettingRow {
                    label: qsTr("Open tab style")
                    Ui.Segmented {
                        options: [{ label: qsTr("Pill"), value: "pill" }, { label: qsTr("Square"), value: "square" }, { label: qsTr("Line"), value: "line" }]
                        value: Theme.tabStyle
                        onPicked: (v) => page.set("tabs/style", v)
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Tab height")
                    Row {
                        spacing: 10
                        Ui.Slide { width: 140; from: 26; to: 44; stepSize: 1; value: Theme.rowHeight; onMoved: page.set("tabs/height", value) }
                        Text { text: Theme.rowHeight + " px"; color: Theme.dim; font.family: Theme.numberFont; font.pixelSize: Theme.px(12); anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Space between tabs")
                    last: true
                    Ui.Segmented {
                        options: [{ label: qsTr("None"), value: 0 }, { label: qsTr("Small"), value: 2 }, { label: qsTr("Large"), value: 6 }]
                        value: Theme.tabGap
                        onPicked: (v) => page.set("tabs/gap", v)
                    }
                }
            }
            Ui.Section {
                title: qsTr("Memory saver")
                Ui.SettingRow {
                    label: qsTr("Put unused tabs to sleep")
                    hint: qsTr("Tabs playing sound or with unsent forms stay awake.")
                    Ui.Segmented {
                        options: [{ label: qsTr("Off"), value: "off" }, { label: qsTr("Balanced"), value: "balanced" }, { label: qsTr("Max"), value: "max" }]
                        value: page.get("memory/saver", "balanced")
                        onPicked: (v) => page.set("memory/saver", v)
                    }
                }
                Ui.SettingRow {
                    visible: page.get("memory/saver", "balanced") === "balanced"
                    label: qsTr("Freeze after")
                    hint: qsTr("A frozen tab keeps its page but stops running")
                    Ui.Segmented {
                        options: [1, 2, 5, 10].map(m => ({ label: m + " min", value: m }))
                        value: Number(page.get("memory/freezeMinutes", 2))
                        onPicked: (v) => page.set("memory/freezeMinutes", v)
                    }
                }
                Ui.SettingRow {
                    visible: page.get("memory/saver", "balanced") === "balanced"
                    label: qsTr("Sleep after")
                    hint: qsTr("A sleeping tab frees its memory and reloads when you click it")
                    last: true
                    Ui.Segmented {
                        options: [5, 10, 30, 60].map(m => ({ label: m + " min", value: m }))
                        value: Number(page.get("memory/discardMinutes", 10))
                        onPicked: (v) => page.set("memory/discardMinutes", v)
                    }
                }
            }
        }
    }
    Component {
        id: newtabPage
        ColumnLayout {
            spacing: 22
            Ui.Section {
                title: qsTr("f1int's new tab page")
                Ui.SettingRow {
                    label: qsTr("Use it for new tabs")
                    hint: qsTr("Otherwise new tabs open your home page")
                    Ui.Toggle { checked: page.get("newtab/mode", "home") === "f1int"; onToggled: page.set("newtab/mode", checked ? "f1int" : "home") }
                }
                Ui.SettingRow {
                    label: qsTr("Widgets, picture and layout")
                    hint: qsTr("Clock, search, shortcuts, notes, to-do, weather and your background")
                    last: true
                    Ui.Pill { text: qsTr("Customise"); onClicked: page.newTabPageRequested() }
                }
            }
        }
    }
    Component {
        id: privacy
        ColumnLayout {
            spacing: 22
            Ui.Section {
                title: qsTr("Blocking and clearing")
                Ui.SettingRow {
                    label: qsTr("Block ads and trackers")
                    hint: qsTr("%1 requests blocked since start. Lists update weekly from easylist.to.").arg(Browser.blockedTotal)
                    Ui.Toggle { checked: page.get("privacy/adblock", true); onToggled: page.set("privacy/adblock", checked) }
                }
                Ui.SettingRow {
                    label: qsTr("Sites can ask to show notifications")
                    hint: qsTr("Off: every request is turned down without asking")
                    Ui.Toggle { checked: page.get("privacy/notifications", true); onToggled: page.set("privacy/notifications", checked) }
                }
                Ui.SettingRow {
                    label: qsTr("Clear browsing data on exit")
                    hint: qsTr("History, cookies, cache and open tabs. Bookmarks are kept.")
                    Ui.Toggle { checked: page.get("privacy/clearOnExit", false); onToggled: page.set("privacy/clearOnExit", checked) }
                }
                Ui.SettingRow {
                    label: qsTr("Clear browsing data now")
                    hint: qsTr("Signs you out of websites")
                    last: true
                    Ui.Pill { text: qsTr("Clear"); onClicked: { Browser.clearBrowsingData(); text = qsTr("Cleared") } }
                }
            }
            Ui.Section {
                title: qsTr("Passwords")
                Ui.SettingRow { label: qsTr("Offer to save passwords"); Ui.Toggle { checked: page.get("passwords/offer", true); onToggled: page.set("passwords/offer", checked) } }
                Ui.SettingRow { label: qsTr("Fill in saved passwords"); Ui.Toggle { checked: page.get("passwords/autofill", true); onToggled: page.set("passwords/autofill", checked) } }
                Ui.SettingRow { label: qsTr("Suggest strong passwords on sign-up forms"); Ui.Toggle { checked: page.get("passwords/generator", true); onToggled: page.set("passwords/generator", checked) } }
                Ui.SettingRow {
                    label: qsTr("Lock passwords after")
                    hint: qsTr("Minutes without using them")
                    Ui.Segmented {
                        options: [{ label: "5", value: 5 }, { label: "15", value: 15 }, { label: "60", value: 60 }, { label: qsTr("Never"), value: 0 }]
                        value: Number(page.get("passwords/autoLockMinutes", 15))
                        onPicked: (v) => page.set("passwords/autoLockMinutes", v)
                    }
                }
                Ui.SettingRow {
                    label: qsTr("Saved passwords")
                    hint: qsTr("Encrypted on this computer (AES-256), never sent anywhere")
                    last: true
                    Ui.Pill { text: qsTr("Open"); onClicked: page.category = "passwords" }
                }
            }
            Ui.Section {
                title: qsTr("What f1int sends")
                Ui.SettingRow {
                    label: qsTr("No telemetry")
                    hint: qsTr("f1int sends nothing about you. It only fetches the ad-block lists from easylist.to once a week.")
                    last: true
                }
            }
        }
    }
    Component {
        id: dataPage
        ImportExport { onOpenPasswords: page.category = "passwords" }
    }
    Component {
        id: downloadsPage
        ColumnLayout {
            spacing: 22
            Ui.Section {
                title: qsTr("Saving files")
                Ui.SettingRow {
                    label: qsTr("Save files to")
                    hint: Browser.profile.downloadPath
                    Ui.Pill { text: qsTr("Change…"); onClicked: folderDialog.open() }
                }
                Ui.SettingRow {
                    label: qsTr("Ask where to save each file")
                    last: true
                    Ui.Toggle { checked: page.get("downloads/ask", false); onToggled: page.set("downloads/ask", checked) }
                }
            }
            FolderDialog {
                id: folderDialog
                onAccepted: { const p = Browser.localPath(selectedFolder); Browser.profile.downloadPath = p; page.set("downloads/path", p) }
            }
        }
    }
    Component {
        id: extensionsPage
        Extensions { onOpenUrl: (u) => page.openUrl(u) }
    }
    Component {
        id: advanced
        ColumnLayout {
            spacing: 22
            Ui.Section {
                id: updates
                title: qsTr("Updates")
                readonly property var up: Browser.updater
                Ui.SettingRow {
                    label: qsTr("f1int %1").arg(updates.up.current)
                    hint: !updates.up.supported ? qsTr("This copy can't update itself (it isn't an installed one). Get new versions from GitHub.")
                          : updates.up.state === "checking" ? qsTr("Checking…")
                          : updates.up.state === "upToDate" ? qsTr("You have the newest version.")
                          : updates.up.state === "available" ? qsTr("Version %1 is ready to download.").arg(updates.up.latest)
                          : updates.up.state === "downloading" ? qsTr("Downloading %1… %2%").arg(updates.up.latest).arg(Math.round(updates.up.progress * 100))
                          : updates.up.state === "ready" ? qsTr("Version %1 is downloaded and checked. f1int restarts to finish; your tabs come back.").arg(updates.up.latest)
                          : updates.up.state === "error" ? updates.up.error
                          : qsTr("Updates come from f1int's releases on GitHub, checked against their fingerprint before installing.")
                    Row {
                        spacing: 8
                        visible: updates.up.supported
                        DotLoader { visible: updates.up.state === "checking" || updates.up.state === "downloading"; anchors.verticalCenter: parent.verticalCenter }
                        Ui.Pill {
                            visible: updates.up.state !== "available" && updates.up.state !== "ready" && updates.up.state !== "downloading"
                            text: qsTr("Check now"); enabled: updates.up.state !== "checking"; onClicked: updates.up.check()
                        }
                        Ui.Pill { visible: updates.up.state === "available"; primary: true; text: qsTr("Download"); onClicked: updates.up.download() }
                        Ui.Pill { visible: updates.up.state === "ready"; primary: true; text: qsTr("Restart and update"); onClicked: updates.up.install() }
                    }
                }
                Ui.SettingRow {
                    visible: updates.up.notes !== "" && (updates.up.state === "available" || updates.up.state === "ready")
                    label: qsTr("What's new")
                    hint: updates.up.notes
                }
                Ui.SettingRow {
                    label: qsTr("Check automatically")
                    hint: qsTr("Once a day. Only asks GitHub which version is newest; nothing about you is sent.")
                    last: true
                    Ui.Toggle { checked: page.get("updates/auto", true); onToggled: page.set("updates/auto", checked) }
                }
            }
            Ui.Section {
                title: qsTr("Getting started")
                Ui.SettingRow {
                    label: qsTr("Welcome tour")
                    hint: qsTr("The intro, importing from other browsers and the first choices")
                    last: true
                    Ui.Pill { text: qsTr("Show"); onClicked: page.welcomeRequested() }
                }
            }
            Ui.Section {
                title: qsTr("How f1int saves memory")
                Ui.SettingRow {
                    label: qsTr("Chromium settings")
                    hint: qsTr("Pages from the same site share one process, at most 6 page processes run, and the back-forward cache is off, so memory stays low. Set F1INT_NO_FLAGS=1 to start without them.")
                    last: true
                }
            }
            Ui.Section {
                title: qsTr("About")
                Ui.SettingRow {
                    label: "f1int " + Browser.version
                    hint: qsTr("Free and open source (MIT). Built on Qt (LGPL) and Chromium. No telemetry.")
                    last: true
                    Image { source: "qrc:/logo/f1int.svg"; sourceSize: Qt.size(64, 64); width: 32; height: 32 }
                }
            }
        }
    }
}
