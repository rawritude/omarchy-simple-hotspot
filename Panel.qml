import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget + popup for sharing the Wi-Fi uplink with a phone.
//
// Deliberately two controls and nothing else: a toggle and a password field.
// The point is to be usable in ten seconds on a plane, not to expose every knob
// NetworkManager has.
Panel {
  id: root
  moduleName: "io.github.rawritude.simple-hotspot"
  ipcTarget: "io.github.rawritude.simple-hotspot"
  manageIpc: false

  // Required: without an implicit size the button's `anchors.fill: parent`
  // collapses to zero and the widget renders nothing, silently.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool verticalBar: bar ? bar.vertical : false

  function boolSetting(name, fallback) {
    var v = root.setting(name, fallback)
    return typeof v === "string" ? v.toLowerCase() === "true" : !!v
  }
  readonly property bool hideWhenOff: root.boolSetting("hideWhenOff", false)

  visible: !hideWhenOff || hotspot.on || root.opened

  // nf-md-access_point: a transmitter with waves either side. Built from its
  // codepoint rather than pasted, since a lost literal renders an invisible
  // widget with no error. Deliberately not the wifi arcs — those are what
  // omarchy.network already shows, and two identical icons in one bar is worse
  // than a less obvious one.
  readonly property string apGlyph: String.fromCodePoint(0xF0003)

  HotspotService {
    id: hotspot
    idlePollMs: root.setting("idlePollMs", 120000)
    activePollMs: root.setting("activePollMs", 3000)
    detailWanted: root.opened
  }

  IpcHandler {
    target: "io.github.rawritude.simple-hotspot"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function on(): void { hotspot.setOn(true) }
    function off(): void { hotspot.setOn(false) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.apGlyph
    active: hotspot.on
    onPressed: function(buttonCode) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(440))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var k = String(t).toLowerCase()
        if (k === "t") hotspot.setOn(!hotspot.on)
        else if (k === "r") hotspot.refresh()
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        Column {
          id: column
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "Hotspot"
            font.family: root.fontFamily
            font.pixelSize: Style.space(13)
            font.bold: true
            color: Color.foreground
          }

          // ---- the toggle ----
          Toggle {
            width: parent.width
            label: hotspot.on ? "Sharing your Wi-Fi" : "Share your Wi-Fi"
            description: hotspot.on
              ? "Phones can join " + hotspot.ssid
              : "Your own connection stays up"
            checked: hotspot.on
            enabled: hotspot.configured && !hotspot.busy
            opacity: enabled ? 1.0 : 0.5
            foreground: Color.foreground
            accent: Color.accent
            fontFamily: root.fontFamily
            onClicked: hotspot.setOn(!hotspot.on)
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: !hotspot.configured
            text: "Set a password below to create the hotspot."
            textFormat: Text.PlainText
            font.family: root.fontFamily
            font.pixelSize: Style.space(10)
            color: root.dim
          }

          PanelSeparator { width: parent.width }

          // ---- network name and password ----
          Text {
            width: parent.width
            visible: hotspot.configured
            text: "Network: " + hotspot.ssid
            textFormat: Text.PlainText
            font.family: root.fontFamily
            font.pixelSize: Style.space(11)
            color: Color.foreground
          }

          Text {
            text: "Password"
            font.family: root.fontFamily
            font.pixelSize: Style.space(10)
            color: root.dim
          }

          TextField {
            id: pwField
            width: parent.width
            // Prefilled with the current password so it is visible when you
            // need to read it out, and editable in place.
            text: hotspot.password
            placeholderText: "At least 8 characters"
            font.family: root.fontFamily
            font.pixelSize: Style.space(11)
            foreground: Color.foreground
            accent: Color.accent
            horizontalPadding: Style.spacing.controlGap
            verticalPadding: Style.spacing.controlPaddingY
            enabled: !hotspot.busy
            onAccepted: hotspot.setPassword(text)
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Press Enter to save. The name and password are remembered, so a "
                + "phone that has joined once reconnects by itself."
            textFormat: Text.PlainText
            font.family: root.fontFamily
            font.pixelSize: Style.space(10)
            color: root.dim
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: hotspot.lastError !== ""
            text: hotspot.lastError
            textFormat: Text.PlainText
            font.family: root.fontFamily
            font.pixelSize: Style.space(10)
            color: Color.urgent
          }

          PanelSeparator { width: parent.width }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "t  toggle sharing    r  refresh"
            font.family: root.fontFamily
            font.pixelSize: Style.space(10)
            color: root.dim
          }
        }
      }
    }
  }
}
