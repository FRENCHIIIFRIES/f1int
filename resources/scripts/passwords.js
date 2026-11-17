// f1int password helper. Runs in a separate script "world": the web page can't see these
// functions or variables, and can't call them. f1int never gives the page any passwords
// except by filling them into the login form, like any password manager.
//
// Page -> f1int: console messages that start with a random secret (NONCE) chosen at
// browser start, so a page can't fake them:   f1int:NONCE:kind:{json}
// f1int -> page: f1int calls __f1intHasLogin(), __f1intFill(user, pass), __f1intFillNew(pass).
(() => {
    const NONCE = "%NONCE%";
    const send = (kind, data) => console.log("f1int:" + NONCE + ":" + kind + ":" + JSON.stringify(data));

    const visible = el => !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
    const passwordFields = root => [...(root || document).querySelectorAll("input[type=password]")].filter(visible);
    const textLike = el => el.tagName === "INPUT" && /^(text|email|tel|)$/i.test(el.getAttribute("type") || "") && visible(el);

    // The username box: the last text/email input before the password box (same form if any).
    function usernameFieldFor(password) {
        const scope = password.form || document;
        let best = null;
        for (const input of scope.querySelectorAll("input"))
            if (textLike(input) && (input.compareDocumentPosition(password) & Node.DOCUMENT_POSITION_FOLLOWING))
                best = input;
        return best;
    }
    // A sign-up or change-password box (rather than a login box).
    const isNewPassword = field =>
        field.autocomplete === "new-password" || passwordFields(field.form || document).length >= 2;

    // Set a value the way a person typing would, so the page's own scripts notice it.
    function setValue(field, value) {
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
        setter.call(field, value);
        field.dispatchEvent(new Event("input", { bubbles: true }));
        field.dispatchEvent(new Event("change", { bubbles: true }));
    }

    // ---- noticing a login ----
    let lastSent = "";
    function capture(form) {
        const filled = passwordFields(form || document).filter(p => p.value);
        if (filled.length) {
            const password = filled[filled.length - 1].value;   // on sign-up forms the last box is the new password
            const user = usernameFieldFor(filled[0]);
            const data = { username: user ? user.value : "", password: password };
            if (JSON.stringify(data) === lastSent) return;      // click + submit of the same form
            lastSent = JSON.stringify(data);
            send("login", data);
            return;
        }
        // Two-step logins (email first, password on the next page): remember the email.
        const user = [...(form || document).querySelectorAll("input")].find(i =>
            textLike(i) && i.value && (i.type === "email" || /user|login|email|identifier/i.test(i.name + i.id + i.autocomplete)));
        if (user) send("username", { username: user.value });
    }
    document.addEventListener("submit", e => capture(e.target), true);
    document.addEventListener("click", e => {
        const button = e.target.closest && e.target.closest("button, input[type=submit], [role=button]");
        if (button) capture(button.form || null);
    }, true);
    document.addEventListener("keydown", e => {
        if (e.key === "Enter" && e.target.tagName === "INPUT") capture(e.target.form || null);
    }, true);

    // ---- clicking into a password box: offer a strong one (sign-up) or fill a saved one (login) ----
    document.addEventListener("focusin", e => {
        const t = e.target;
        if (t.tagName !== "INPUT" || t.type !== "password") return;
        if (isNewPassword(t)) { if (!t.value) send("newpassword", {}); }
        else send("passwordfocus", {});   // a login box (maybe added after the page loaded): f1int can fill it
    }, true);

    // ---- called by f1int ----
    window.__f1intHasLogin = () => passwordFields().length > 0;
    window.__f1intFill = (username, password) => {
        const fields = passwordFields().filter(p => !isNewPassword(p));
        const target = fields[0] || passwordFields()[0];
        if (!target) return false;
        const user = usernameFieldFor(target);
        if (user && username) setValue(user, username);
        setValue(target, password);
        return true;
    };
    window.__f1intFillNew = password => {
        const fields = passwordFields().filter(isNewPassword);
        fields.forEach(f => setValue(f, password));
        return fields.length;
    };
})();
