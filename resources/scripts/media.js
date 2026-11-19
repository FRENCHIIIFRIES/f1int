// f1int media controls. Runs only when you press a button, in f1int's separate script world
// (the page can't see or change it). Finds the page's audio/video, does `action`, and
// reports what's playing. Media inside frames (some embedded players) isn't reached.
// Players that keep their audio off the page (Spotify) are read from the page's "now playing"
// information instead, and driven with their own buttons.
(function (action) {
    const all = Array.from(document.querySelectorAll('video, audio'));
    const isPlaying = (e) => !e.paused && !e.ended;
    const playing = all.find(isPlaying);
    // What to act on: what's playing, else the one paused last (it has progress), else the first.
    const target = playing || all.filter((e) => e.currentTime > 0).pop() || all[0];
    const session = navigator.mediaSession;
    const meta = session && session.metadata;
    if (!target && !meta) return null;

    // The player's own buttons, for sites known to work and a common pattern for others.
    const buttons = {
        toggle: '[data-testid="control-button-playpause"], #play-pause-button, .ytp-play-button, .playControls__play',
        next: '[data-testid="control-button-skip-forward"], .next-button, .ytp-next-button, .playControls__next, button[aria-label^="Next" i]',
        previous: '[data-testid="control-button-skip-back"], .previous-button, .ytp-prev-button, .playControls__prev, button[aria-label^="Previous" i]'
    };
    const press = (kind) => {
        const b = Array.from(document.querySelectorAll(buttons[kind])).find((el) => el.offsetParent !== null || el.getClientRects().length);
        if (b) b.click();
        return !!b;
    };
    let nowPlaying = playing ? true : !!session && session.playbackState === 'playing';

    if (action === 'toggle') {
        if (!target) { press('toggle'); nowPlaying = !nowPlaying; }
        else if (playing) { playing.pause(); nowPlaying = false; }
        else { target.play().catch(() => {}); nowPlaying = true; }
    } else if (action === 'next' || action === 'previous') {
        if (!press(action) && target && action === 'previous') target.currentTime = 0;   // no button: start again
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

    const art = meta && meta.artwork && meta.artwork.length ? meta.artwork[meta.artwork.length - 1].src : '';
    const has = (kind) => !!document.querySelector(buttons[kind]);
    return {
        playing: nowPlaying,
        title: (meta && meta.title) || '',
        artist: (meta && meta.artist) || '',
        art: /^https:/.test(art) ? art : '',
        canSkip: has('next'),
        video: all.some((e) => e.tagName === 'VIDEO' && e.videoWidth > 0)
    };
})
