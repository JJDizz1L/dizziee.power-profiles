import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "dizziee.power-profiles"
  ipcTarget: "dizziee.power-profiles"
  property var profiles: []
  property string activeProfile: ""
  property int profileIndex: 0
  property bool cursorActive: false
  // True while the panel is freshly opened or recently interacted with; the
  // poll timer below only runs then, so a forgotten-open panel goes quiet.
  property bool pollActive: false

  // Disk cache (flat file in the existing ~/.cache/omarchy dir, no mkdir
  // needed): last-known profiles for an accurate bar tooltip from boot,
  // with zero spawns until the panel is first opened.
  readonly property string cachePath: {
    var base = Quickshell.env("XDG_CACHE_HOME")
    if (!base) base = Quickshell.env("HOME") + "/.cache"
    return base + "/omarchy/dizziee.power-profiles.json"
  }

  function pokeIdle() {
    pollActive = true
    idleTimer.restart()
  }

  function applyCache(text) {
    try {
      var data = JSON.parse(String(text || "{}"))
      if (!data || !Array.isArray(data.profiles) || data.profiles.length === 0) return
      profiles = data.profiles
      if (typeof data.activeProfile === "string") activeProfile = data.activeProfile
      var idx = profiles.indexOf(activeProfile)
      profileIndex = idx >= 0 ? idx : 0
    } catch (e) {}
  }

  function writeCache() {
    try {
      cacheFile.setText(JSON.stringify({ profiles: profiles, activeProfile: activeProfile }))
    } catch (e) {}
  }

  function selectProfileByDelta(delta) {
    pokeIdle()
    profileIndex = Model.selectProfileIndex(profileIndex, delta, profiles)
  }

  function activateSelectedProfile() {
    if (profileIndex < 0 || profileIndex >= profiles.length) return
    setProfile(profiles[profileIndex])
  }

  function profileIcon(name) {
    return Model.profileIcon(name)
  }

  readonly property string barIcon: "󰠠"

  function refresh() {
    if (!profilesProc.running) profilesProc.running = true
  }

  function updateProfiles(raw) {
    var parsed = Model.parseProfiles(raw, profileIndex)
    if (parsed.profiles.length === 0) return
    var changed = parsed.activeProfile !== activeProfile
      || JSON.stringify(parsed.profiles) !== JSON.stringify(profiles)
    profiles = parsed.profiles
    activeProfile = parsed.activeProfile
    profileIndex = parsed.profileIndex
    if (opened && activeProfile !== "") {
      var idx = profiles.indexOf(activeProfile)
      if (idx >= 0) profileIndex = idx
    }
    // One small disk write per actual change, not per poll.
    if (changed) writeCache()
  }

  function setProfile(profile) {
    if (!profile || actionProc.running) return
    pokeIdle()
    actionProc.command = ["powerprofilesctl", "set", profile]
    actionProc.running = true
  }

  onOpenedChanged: {
    if (opened) {
      pokeIdle()
      refresh()
      var idx = profiles.indexOf(activeProfile)
      profileIndex = idx >= 0 ? idx : 0
      cursorActive = false
    } else {
      pollActive = false
      idleTimer.stop()
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: profilesProc
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateProfiles(text)
    }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  Timer {
    interval: 5000
    running: root.opened && root.pollActive
    repeat: true
    onTriggered: root.refresh()
  }

  // A minute after the last open/interaction, polling stops even if the
  // panel is still up; the next interaction or reopen re-arms it.
  Timer {
    id: idleTimer
    interval: 60000
    onTriggered: root.pollActive = false
  }

  FileView {
    id: cacheFile
    path: root.cachePath
    watchChanges: false
    printErrors: false
    onLoaded: root.applyCache(text())
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barIcon
    fixedWidth: root.bar && root.bar.vertical ? -1 : Style.space(27)
    fixedHeight: root.bar && root.bar.vertical ? Style.space(26) : -1
    tooltipText: root.activeProfile ? "Power: " + root.activeProfile : "Power Profiles"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dx !== 0) root.selectProfileByDelta(dx)
        else if (dy !== 0) root.selectProfileByDelta(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateSelectedProfile()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Column {
          width: parent.width
          spacing: Style.space(10)

          Text {
            width: parent.width
            text: "Power Profiles"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Row {
            id: profileRow
            width: parent.width
            spacing: Style.space(6)

            readonly property real cellWidth: root.profiles.length > 0
              ? (width - spacing * (root.profiles.length - 1)) / root.profiles.length
              : 0

            Repeater {
              model: root.profiles
              Button {
                required property var modelData
                required property int index
                width: profileRow.cellWidth
                iconText: root.profileIcon(String(modelData))
                iconSize: Style.font.title
                text: String(modelData).charAt(0).toUpperCase() + String(modelData).slice(1)
                fontSize: Style.font.bodySmall
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.activeProfile === modelData
                hasCursor: root.cursorActive && root.profileIndex === index
                onClicked: root.setProfile(modelData)
                onHovered: function(h) {
                  if (h) {
                    root.cursorActive = true
                    root.profileIndex = index
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
