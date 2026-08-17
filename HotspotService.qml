import QtQuick
import Quickshell.Io

// Drives the `hotspot-share` helper.
//
// The helper does the interesting parts: it finds the current uplink, reads the
// channel it is on, creates a virtual AP interface, and pins the hotspot to
// that same channel — the radio reports `#{ AP } <= 1 ... #channels <= 1`, so
// the AP physically cannot sit on a different channel from the uplink. Because
// the channel changes between one network and the next, it is re-read on every
// start rather than stored.
//
// NetworkManager provides the AP, DHCP, DNS and NAT through `ipv4.method
// shared`, so there is no hostapd or dnsmasq configuration anywhere — only the
// dnsmasq binary, which NM spawns itself.
//
// Polling rather than D-Bus signals here, deliberately: NetworkManager emits a
// great deal of traffic (every scan, every state change) and the hotspot state
// changes perhaps twice a day, almost always from this widget. A slow heartbeat
// costs less than filtering that firehose.
Item {
  id: svc

  property int idlePollMs: 120000
  property int activePollMs: 3000
  property bool detailWanted: false

  property bool on: false
  property string ssid: ""
  property string password: ""
  property bool configured: false     // a password has been set at least once
  property string lastError: ""
  property bool busy: false

  readonly property int pollInterval: detailWanted ? activePollMs : idlePollMs

  signal refreshed()

  function refresh() {
    if (infoProc.running) return
    infoProc.running = true
  }

  Process {
    id: infoProc
    command: ["hotspot-share", "info"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // "ssid|password|state"
        var parts = String(text || "").trim().split("|")
        if (parts.length >= 3) {
          svc.ssid = parts[0]
          svc.password = parts[1]
          svc.on = parts[2] === "on"
          svc.configured = svc.ssid !== ""
        } else {
          svc.configured = false
          svc.on = false
        }
        svc.refreshed()
      }
    }
    onExited: function(code) { if (code !== 0) svc.configured = false }
  }

  // ---- actions --------------------------------------------------------
  //
  // Every argument is an argv element. The password in particular comes from a
  // text field, and putting user-typed text into a shell string is the same
  // class of bug as a SQL injection — there is no shell anywhere in this file.
  function setOn(want) {
    if (actionProc.running) return
    svc.busy = true
    svc.lastError = ""
    actionProc.command = ["hotspot-share", want ? "on" : "off"]
    actionProc.running = true
  }

  function setPassword(pw) {
    if (actionProc.running) return
    if (String(pw).length < 8) { svc.lastError = "WPA2 needs at least 8 characters"; return }
    svc.busy = true
    svc.lastError = ""
    actionProc.command = ["hotspot-share", "set-password", String(pw)]
    actionProc.running = true
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var t = String(text || "").trim()
        if (t !== "") svc.lastError = t.replace(/^ERR:\s*/, "")
      }
    }
    onExited: function(code) {
      svc.busy = false
      // Turning the AP up takes a moment to settle; re-read rather than assume.
      Qt.callLater(svc.refresh)
      settle.restart()
    }
  }

  // A second look after the interface has had time to come up or go away.
  Timer { id: settle; interval: 2500; repeat: false; onTriggered: svc.refresh() }

  // Guards against a wedged helper leaving `busy` stuck, which would disable
  // the toggle permanently.
  Timer {
    id: actionTimeout
    interval: 20000
    repeat: false
    onTriggered: if (actionProc.running) {
      actionProc.running = false
      svc.busy = false
      svc.lastError = "hotspot-share timed out"
    }
  }
  Connections {
    target: actionProc
    function onRunningChanged() {
      if (actionProc.running) actionTimeout.restart(); else actionTimeout.stop()
    }
  }

  onDetailWantedChanged: if (detailWanted) refresh()

  Timer {
    interval: svc.pollInterval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: svc.refresh()
  }
}
