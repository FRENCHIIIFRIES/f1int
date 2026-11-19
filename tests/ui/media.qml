import QtQuick
import f1int

// Media controls with a player like Spotify's: no audio element on the page, only its
// "now playing" information and its own buttons (test profile only).
Item {
    id: test
    property var win
    property int step: 0
    function check(ok, what) { console.warn((ok ? "PASS " : "FAIL ") + what) }
    readonly property string player: "<html><body style='font:16px sans-serif;padding:40px'><h2>Player</h2>" +
        "<button data-testid='control-button-skip-back' onclick=\"document.title='prev'\">Prev</button>" +
        "<button data-testid='control-button-playpause' onclick=\"document.title='toggle'\">Play</button>" +
        "<button data-testid='control-button-skip-forward' onclick=\"document.title='next'\">Next</button>" +
        "<script>navigator.mediaSession.metadata = new MediaMetadata({ title: 'Test Song', artist: 'Test Band'," +
        " artwork: [{ src: 'https://example.com/cover.png', sizes: '300x300' }] }); navigator.mediaSession.playbackState = 'playing'</script></body></html>"
    Timer {
        interval: 1200
        repeat: true
        running: true
        onTriggered: {
            const w = test.win
            if (test.step === 1 && w.view.loading) return
            switch (test.step++) {
            case 0: w.view.loadHtml(test.player, "https://player.test/"); break
            case 1: w.mediaTabId = w.tabs.currentId; w.refreshMedia(); break   // = the tab started playing
            case 2: { const m = w.mediaCard
                      test.check(m !== null && m.title === "Test Song" && m.artist === "Test Band", "now playing read from the page: " + (m ? m.title : "none"))
                      test.check(m && m.art === "https://example.com/cover.png", "album art")
                      test.check(m && m.canSkip && m.playing, "next/previous offered, shown as playing")
                      console.warn("SHOT media-card")
                      w.mediaAction("next"); break }
            case 3: w.view.runJavaScript("document.title", (t) => test.check(t === "next", "next uses the player's own button"))
                    w.mediaAction("previous"); break
            case 4: w.view.runJavaScript("document.title", (t) => test.check(t === "prev", "previous too"))
                    w.mediaAction("toggle"); break
            case 5: w.view.runJavaScript("document.title", (t) => test.check(t === "toggle", "play/pause too")); break
            case 6: console.warn("DONE"); running = false; break
            }
        }
    }
}
