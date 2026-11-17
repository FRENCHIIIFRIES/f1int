import QtQuick
import f1int

// Local profiles (test family only, never your real profiles): add, rename, picture, delete.
Item {
    id: test
    property var win
    property int step: 0
    property string id: ""
    readonly property url picture: Qt.resolvedUrl("../../resources/logo/f1int-256.png")
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    function find(pid) { return Browser.profiles.list.find(p => p.id === pid) }
    Timer {
        interval: 800
        repeat: true
        running: true
        onTriggered: {
            const P = Browser.profiles
            switch (test.step++) {
            case 0:
                test.check(P.list.length >= 1 && P.list[0].current, "the first profile is there and open")
                test.id = P.add("  Work  ")
                test.check(test.find(test.id) && test.find(test.id).name === "Work", "added with a trimmed name")
                break
            case 1:
                P.rename(test.id, "Work stuff")
                test.check(test.find(test.id).name === "Work stuff", "renamed")
                test.check(P.setPicture(test.id, test.picture), "picture set")
                test.check(String(test.find(test.id).picture).indexOf(".png") > 0, "picture listed")
                test.check(!P.setPicture(test.id, Qt.resolvedUrl("profiles.qml")), "a non-image is refused")
                test.check(!P.setPicture("../evil", test.picture), "a bad id is refused")
                break
            case 2:
                test.check(P.remove("") !== "", "the first profile can't be deleted")
                test.check(P.remove(P.current) !== "" || P.current === "", "this profile can't be deleted")
                test.check(P.remove(test.id) === "", "deleted")
                test.check(test.find(test.id) === undefined, "gone from the list")
                win.panel = "settings"
                break
            case 3: console.warn("SHOT profiles-settings"); break
            case 4: console.warn("DONE"); running = false; break
            }
        }
    }
}
