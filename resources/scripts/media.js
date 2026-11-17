// f1int media controls. Runs only when you press a button, in f1int's separate script world
// (the page can't see or change it). Finds the page's audio/video, does `action`, and
// reports what's playing. Media inside frames (some embedded players) isn't reached.
(function (action) {
    const all = Array.from(document.querySelectorAll('video, audio'));
    const isPlaying = (e) => !e.paused && !e.ended;
    const playing = all.find(isPlaying);
    // What to act on: what's playing, else the one paused last (it has progress), else the first.
    const target = playing || all.filter((e) => e.currentTime > 0).pop() || all[0];
    if (!target) return null;
    let nowPlaying = !!playing;

    if (action === 'toggle') {
        if (playing) { playing.pause(); nowPlaying = false; }
        else { target.play().catch(() => {}); nowPlaying = true; }
    } else if (action === 'pip-on') {
        // Make one video fill the page, so the small pop-out window shows just the video.
        const videos = all.filter((e) => e.tagName === 'VIDEO');
        const area = (v) => v.getBoundingClientRect().width * v.getBoundingClientRect().height;
        const video = videos.find(isPlaying) || videos.sort((a, b) => area(b) - area(a))[0];
        if (!video) return null;
        video.setAttribute('data-f1int-pip', '');
        if (!document.getElementById('f1int-pip-style')) {
            const style = document.createElement('style');
            style.id = 'f1int-pip-style';
            style.textContent = '[data-f1int-pip]{position:fixed!important;inset:0!important;width:100vw!important;' +
                'height:100vh!important;max-width:none!important;max-height:none!important;margin:0!important;' +
                'transform:none!important;z-index:2147483647!important;background:#000!important;object-fit:contain!important}' +
                'html,body{overflow:hidden!important}';
            document.documentElement.appendChild(style);
        }
    } else if (action === 'pip-off') {
        document.querySelectorAll('[data-f1int-pip]').forEach((e) => e.removeAttribute('data-f1int-pip'));
        const style = document.getElementById('f1int-pip-style');
        if (style) style.remove();
    }

    const meta = navigator.mediaSession && navigator.mediaSession.metadata;
    return {
        playing: nowPlaying,
        title: (meta && meta.title) || '',
        artist: (meta && meta.artist) || '',
        video: all.some((e) => e.tagName === 'VIDEO')
    };
})
