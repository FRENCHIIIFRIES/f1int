import QtQuick
import f1int

// Google sign-in must not say "This browser or app may not be secure". Types a made-up
// address (never a real account) and presses Next; then checks other sites still load.
//   tools\ui-test.ps1 tests\ui\google.qml -Name f1int-test-google -Urls "https://www.wikipedia.org"
Item {
    id: test
    property var win
    property int step: 0
    property int waited: 0
    function say(text) { console.warn("SHOT " + text) }
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    function log(text) { console.warn("INFO " + text) }
    readonly property string identity: "navigator.userAgent + ' | brands: ' + " +
        "(navigator.userAgentData ? navigator.userAgentData.brands.map(b => b.brand + ' ' + b.version).join(', ') : 'none')"
    function waitLoaded() {   // true once the page finished (gives up after ~20 s)
        if (win.view.loading && waited++ < 13) return false
        waited = 0
        return true
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            switch (test.step) {
            case 0:
                if (!test.waitLoaded()) return
                w.view.runJavaScript(test.identity, (r) => test.log("identity on " + w.view.url + ": " + r))
                w.view.url = "https://accounts.google.com/ServiceLogin"
                break
            case 1:
                if (!test.waitLoaded()) return
                w.view.runJavaScript(test.identity, (r) => test.log("identity on accounts.google.com: " + r))
                test.say("google-signin")
                break
            case 2:   // type the address the way a person would (input events), then press Next
                w.view.runJavaScript(
                    "(() => { const box = document.querySelector('#identifierId'); if (!box) return 'no email box';" +
                    " box.focus(); const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;" +
                    " set.call(box, 'f1int.signin.check@gmail.com');" +
                    " box.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText' }));" +
                    " box.dispatchEvent(new Event('change', { bubbles: true }));" +
                    " const next = document.querySelector('#identifierNext button') || document.querySelector('#identifierNext');" +
                    " if (!next) return 'no Next button'; next.click(); return 'clicked Next' })()",
                    (r) => test.log(r))
                break
            case 3: case 4: case 5: break   // Google takes a moment
            case 6:
                w.view.runJavaScript("document.body.innerText", (text) => {
                    const t = String(text)
                    test.log("page says: " + t.replace(/\s+/g, " ").slice(0, 300))
                    const blocked = /may not be secure|Couldn.t sign you in|browser or app/i.test(t)
                    const through = /Enter your password|Couldn.t find (your Google Account|this account)/i.test(t)
                    test.check(!blocked, "Google doesn't call the browser insecure")
                    test.check(through, "Google asks for the password or says the account doesn't exist")
                })
                w.view.runJavaScript(test.identity, (r) => test.log("identity after Next: " + r))
                test.say("google-after-next")
                break
            case 7: w.view.url = "https://www.google.com"; break
            case 8:
                if (!test.waitLoaded()) return
                w.view.runJavaScript("document.title + ' | ' + !!document.querySelector('textarea[name=q], input[name=q]')",
                                     (r) => test.check(String(r).indexOf("Google | true") === 0, "google.com loads with its search box (" + r + ")"))
                w.view.runJavaScript(test.identity, (r) => test.log("identity on www.google.com: " + r))
                test.say("google-home")
                break
            case 9: w.view.url = "https://www.wikipedia.org"; break
            case 10:
                if (!test.waitLoaded()) return
                w.view.runJavaScript("document.title", (r) => test.check(String(r).indexOf("Wikipedia") >= 0, "wikipedia.org loads (" + r + ")"))
                w.view.runJavaScript(test.identity, (r) => test.log("identity on wikipedia: " + r))
                test.say("wikipedia")
                break
            case 11: console.warn("DONE"); running = false; break
            }
            test.step++
        }
    }
}
