import QtQuick
import QtMultimedia

// A single video clip: MediaPlayer + VideoOutput + poster frames.
// The poster sits under the VideoOutput, so it shows instead of black until the first frame arrives.
Item {
    id: layer

    property url source
    property url poster                 // first frame (shown while the video isn't ready)
    property url endPoster              // last frame (in case the backend drops it after EndOfMedia)
    property bool looping: false
    property bool freezeAtEnd: false    // pause ~2 frames before the end and hold there
    property real endLead: 0            // emit nearEnd() this many seconds before the end

    readonly property bool failed: player.error !== MediaPlayer.NoError
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property bool frozen: _frozen

    property bool _frozen: false
    property bool _ended: false
    property bool _nearEndFired: false
    property bool _finishedFired: false

    signal nearEnd()
    signal finished()

    // Rewind and hold on the first frame (preload).
    function prepare() {
        _reset()
        player.setPosition(0)
        player.pause()
    }
    function start() {
        _reset()
        player.play()
    }
    function restart() {
        _reset()
        player.setPosition(0)
        player.play()
    }
    function hold() { player.pause() }

    function _reset() {
        _frozen = false
        _ended = false
        _nearEndFired = false
        _finishedFired = false
    }
    function _fireNearEnd() {
        if (_nearEndFired) return
        _nearEndFired = true
        nearEnd()
    }
    function _fireFinished() {
        if (_finishedFired) return
        _finishedFired = true
        _fireNearEnd()
        finished()
    }

    Image {
        anchors.fill: parent
        source: layer.poster
        fillMode: Image.PreserveAspectCrop
        visible: source != ""
        cache: true
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    Image {
        anchors.fill: parent
        source: layer.endPoster
        fillMode: Image.PreserveAspectCrop
        visible: source != "" && (layer._ended || layer.failed)
        cache: true
    }

    MediaPlayer {
        id: player
        source: layer.source
        videoOutput: output
        // No audio: no audioOutput assigned.
        loops: layer.looping ? MediaPlayer.Infinite : 1

        onPositionChanged: {
            var pos = player.position, dur = player.duration
            if (dur <= 0 || layer.looping)
                return
            if (layer.endLead > 0 && pos >= dur - layer.endLead * 1000)
                layer._fireNearEnd()
            if (layer.freezeAtEnd && !layer._frozen && pos >= dur - 70) {
                player.pause()
                layer._frozen = true
                layer._fireFinished()
            }
        }
        onMediaStatusChanged: {
            if (player.mediaStatus === MediaPlayer.EndOfMedia && !layer.looping) {
                layer._ended = true
                if (layer.freezeAtEnd)
                    layer._frozen = true
                layer._fireFinished()
            }
        }
        onErrorOccurred: (error, errorString) => {
            console.warn("spidey: video error", layer.source, errorString)
            // Don't let the flow get stuck if a video can't play.
            layer._fireFinished()
        }
    }
}
