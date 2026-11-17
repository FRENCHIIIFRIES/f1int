import QtQuick
import QtWebEngine
import f1int

// UI walk-through of the password manager, in the separate test profile:
// create vault -> submit a login -> save prompt -> save -> autofill -> panel -> lock -> sign-up suggestion.
Item {
    id: test
    property var win
    property int step: 0
    function say(text) { console.warn("SHOT " + text) }
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    readonly property string loginPage: "<html><body style='background:#fff;font:16px sans-serif;padding:40px'>" +
        "<h2>Log in to Example</h2><form action='/done'><p><input name=email type=email></p>" +
        "<p><input name=pw type=password></p><button>Log in</button></form></body></html>"
    readonly property string signupPage: "<html><body style='background:#fff;font:16px sans-serif;padding:40px'>" +
        "<h2>Create an account</h2><form><p><input name=email type=email></p>" +
        "<p><input id=p1 type=password autocomplete=new-password></p><p><input type=password autocomplete=new-password></p>" +
        "<button>Sign up</button></form></body></html>"

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            const v = Browser.passwords
            // Steps that use the page wait until it has finished loading.
            if ([1, 4, 10].indexOf(test.step) >= 0 && w.view.loading) return
            switch (test.step++) {
            case 0:
                test.check(v.setUp("test master password", false), "vault created")
                w.view.loadHtml(test.loginPage, "https://login.test/")
                break
            case 1:   // type like a person (in the page's own world) and press the button
                w.view.runJavaScript("document.querySelector('[name=email]').value='ana@example.com';" +
                                     "document.querySelector('[name=pw]').value='Very-Strong-Pass-42';" +
                                     "document.querySelector('button').click()")
                break
            case 2:
                test.check(w.savePrompt !== null && w.savePrompt.username === "ana@example.com", "save prompt after login")
                test.say("save-prompt")
                break
            case 3:
                w.savePassword()
                test.check(v.loginsFor("https://login.test/").length === 1, "password saved")
                w.view.loadHtml(test.loginPage, "https://login.test/")   // visit again
                break
            case 4:
                w.view.runJavaScript("document.querySelector('[name=email]').value + '|' + document.querySelector('[name=pw]').value",
                                     (r) => test.check(r === "ana@example.com|Very-Strong-Pass-42", "saved login filled in"))
                test.check(w.view.hasLoginForm, "key button shown on the login page")
                test.say("autofilled")
                break
            case 5: w.panel = "passwords"; break
            case 6: test.say("passwords-panel"); break
            case 7: v.lock(); break
            case 8: test.check(v.state === "locked", "locks"); test.say("passwords-locked"); break
            case 9: v.unlock("test master password"); w.panel = ""; w.view.loadHtml(test.signupPage, "https://signup.test/"); break
            case 10:   // = clicking into the box (a background test window gets no real focus events)
                w.view.runJavaScript("document.getElementById('p1').dispatchEvent(new FocusEvent('focusin', { bubbles: true }))")
                break
            case 11:
                test.check(w.suggestion !== null && w.suggestion.password.length === 20, "strong password suggested on sign-up")
                test.say("suggestion")
                break
            case 12:
                v.forgetVault()
                console.warn("DONE")
                running = false
                break
            }
        }
    }
}