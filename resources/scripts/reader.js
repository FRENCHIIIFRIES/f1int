// f1int reading view. Runs in f1int's separate script world when you press the reading
// button: finds the article on the page and shows just its text and pictures, in a clean
// layout over the page. Its own styles live in a closed shadow root, so the page's CSS
// and scripts can't reach them. Closing it puts the page back exactly as it was.
(function (on, look) {
    const ID = 'f1int-reader';
    const tell = (kind, data) => console.log('f1int:%NONCE%:' + kind + ':' + JSON.stringify(data));
    const old = document.getElementById(ID);
    if (old) { old.remove(); document.documentElement.style.overflow = old.dataset.overflow || ''; }
    if (!on) return 'off';

    // ---- find the article: the block that holds the most paragraph text ----
    const scores = new Map();
    for (const p of document.querySelectorAll('p, pre, blockquote')) {
        const len = p.textContent.trim().length;
        if (len < 40 || p.closest('nav, aside, footer, header, form')) continue;
        const parent = p.parentElement, grand = parent && parent.parentElement;
        if (parent) scores.set(parent, (scores.get(parent) || 0) + len);
        if (grand) scores.set(grand, (scores.get(grand) || 0) + len / 2);
    }
    let best = null, bestScore = 0;
    for (const [el, s] of scores) if (s > bestScore) { best = el; bestScore = s; }
    if (!best || bestScore < 500) return 'none';

    // ---- a clean copy: text, headings, lists, quotes, code, tables, pictures ----
    const article = best.cloneNode(true);
    const junk = /(comment|share|social|related|promo|advert|sponsor|newsletter|subscribe|cookie|banner|popup|footer|sidebar)/i;
    article.querySelectorAll('script, style, noscript, iframe, form, button, input, select, textarea, nav, aside, svg, canvas, object, embed, [hidden], [aria-hidden="true"]')
        .forEach((e) => e.remove());
    article.querySelectorAll('*').forEach((e) => {
        if (junk.test((e.id || '') + ' ' + (typeof e.className === 'string' ? e.className : ''))) { e.remove(); return; }
        if (e.tagName === 'IMG' && !e.getAttribute('src')) {   // lazy-loaded pictures keep the real address elsewhere
            const real = e.getAttribute('data-src') || e.getAttribute('data-lazy-src') || e.getAttribute('data-original');
            if (real) e.setAttribute('src', real); else { e.remove(); return; }
        }
        for (const a of Array.from(e.attributes))
            if (!['href', 'src', 'srcset', 'alt', 'colspan', 'rowspan'].includes(a.name)) e.removeAttribute(a.name);
        if (e.tagName === 'A') { e.href = e.href; e.target = '_blank'; e.rel = 'noopener'; }   // absolute links
        if (e.tagName === 'IMG') e.src = e.src;   // absolute address
    });

    const h1 = document.querySelector('h1');
    const title = (h1 && h1.textContent.trim()) || document.title;
    article.querySelectorAll('h1').forEach((e) => { if (e.textContent.trim() === title) e.remove(); });
    const author = document.querySelector('meta[name="author"]');
    const words = article.textContent.trim().split(/\s+/).length;

    // ---- the overlay ----
    const host = document.createElement('div');
    host.id = ID;
    host.dataset.overflow = document.documentElement.style.overflow;
    host.style.cssText = 'all:initial;position:fixed;inset:0;z-index:2147483647;';
    const root = host.attachShadow({ mode: 'closed' });
    const serif = look.font === 'serif';
    root.innerHTML = `<style>
        :host { all: initial; }
        .page { position: fixed; inset: 0; overflow: auto; background: ${look.bg}; color: ${look.fg};
                font: ${look.size}px/1.7 ${serif ? 'Charter, "Iowan Old Style", Georgia, serif' : '"Segoe UI Variable Text", "Segoe UI", system-ui, sans-serif'}; }
        .bar { position: sticky; top: 0; display: flex; gap: 6px; justify-content: flex-end; padding: 12px 16px;
               background: ${look.bg}; border-bottom: 1px solid ${look.line}; font: 13px system-ui, sans-serif; }
        .bar button { all: unset; cursor: pointer; padding: 6px 12px; border-radius: 999px; color: ${look.fg}; background: ${look.field}; }
        .bar button:hover { background: ${look.line}; }
        .bar button:focus-visible { outline: 2px solid ${look.accent}; outline-offset: 2px; }
        article { max-width: ${look.width}px; margin: 0 auto; padding: 48px 24px 120px; }
        .site { color: ${look.dim}; font-size: 0.8em; margin-bottom: 8px; }
        h1 { font-size: 2em; line-height: 1.2; margin: 0 0 12px; letter-spacing: -0.01em; }
        .meta { color: ${look.dim}; font-size: 0.8em; margin-bottom: 36px; }
        h2, h3, h4 { line-height: 1.3; margin: 1.6em 0 0.5em; }
        p, ul, ol, blockquote, pre, table, figure { margin: 0 0 1.1em; }
        a { color: ${look.accent}; }
        img, video, picture { max-width: 100%; height: auto; border-radius: 8px; display: block; margin: 0 auto; }
        figcaption { color: ${look.dim}; font-size: 0.8em; text-align: center; margin-top: 6px; }
        blockquote { border-left: 3px solid ${look.accent}; margin-left: 0; padding-left: 18px; color: ${look.dim}; }
        pre, code { font-family: Consolas, "Cascadia Mono", monospace; font-size: 0.85em; }
        pre { background: ${look.field}; padding: 14px; border-radius: 8px; overflow: auto; }
        table { border-collapse: collapse; width: 100%; font-size: 0.85em; }
        td, th { border: 1px solid ${look.line}; padding: 6px 8px; }
    </style>
    <div class="page"><div class="bar">
        <button data-do="smaller" title="Smaller text">A−</button>
        <button data-do="bigger" title="Bigger text">A+</button>
        <button data-do="font">${serif ? 'Sans' : 'Serif'}</button>
        <button data-do="close" title="Close reading view (Esc)">Close</button>
    </div><article><div class="site"></div><h1></h1><div class="meta"></div></article></div>`;
    root.querySelector('.site').textContent = location.hostname.replace(/^www\./, '');
    root.querySelector('h1').textContent = title;
    root.querySelector('.meta').textContent =
        (author ? author.content + '  ·  ' : '') + Math.max(1, Math.round(words / 230)) + ' min read';
    root.querySelector('article').append(...Array.from(article.childNodes));

    const close = () => {
        host.remove();
        document.documentElement.style.overflow = host.dataset.overflow || '';
        removeEventListener('keydown', onKey, true);
        tell('reader', { on: false });
    };
    const onKey = (e) => { if (e.key === 'Escape') { e.stopPropagation(); close(); } };
    addEventListener('keydown', onKey, true);
    root.querySelector('.bar').addEventListener('click', (e) => {
        const what = e.target.dataset && e.target.dataset.do;
        if (what === 'close') close();
        else if (what) tell('readerlook', { change: what });   // f1int saves it and redraws
    });
    document.documentElement.appendChild(host);
    document.documentElement.style.overflow = 'hidden';
    root.querySelector('.page').focus();
    return 'on';
})
