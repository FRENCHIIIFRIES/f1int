import QtQuick
import f1int

// Installs a real extension from the Chrome Web Store into the test profile (network needed).
Item {
    id: test
    property var win
    property int step: 0
    property int waits: 0
    property string result: ""
    readonly property string storeUrl: "https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh"
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    Connections { target: Browser; function onExtensionAdded(name, error) { test.result = error ? "error: " + error : "installed: " + name } }
    Connections { target: Browser; function onWebStoreFailed(id, error) { test.result = "failed: " + error } }
    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            switch (test.step++) {
            case 0: test.check(Browser.webStoreId(test.storeUrl) === "ddkjiahejlhfcafbddmgiahcphecmpfh", "store link recognised")
                    w.view.url = test.storeUrl; break
            case 1: Browser.installFromWebStore(Browser.webStoreId(test.storeUrl)); break
            case 2: if (test.result === "" && ++test.waits < 30) { test.step--; break }
                    test.check(test.result.startsWith("installed"), "installed from the store: " + test.result)
                    test.check(Browser.profile.extensionManager.extensions.length > 0, "listed in Extensions")
                    console.warn("SHOT webstore-page"); break
            case 3: console.warn("DONE"); running = false; break
            }
        }
    }
}
