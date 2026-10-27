// The cache is user-writable and command output is external input. Keep the
// list tiny and every profile name a plain string before it reaches a button
// or the powerprofilesctl argv.
var MAX_PROFILES = 16
var MAX_PROFILE_NAME = 64

function cleanProfileName(value) {
  if (typeof value !== "string") return ""
  var name = value.trim()
  if (!name || name.length > MAX_PROFILE_NAME) return ""
  if (name.charAt(0) === "-") return ""
  return name
}

function clampIndex(index, length) {
  if (length <= 0) return 0
  return Math.max(0, Math.min(length - 1, index))
}

function selectProfileIndex(index, delta, profiles) {
  var values = Array.isArray(profiles) ? profiles : []
  if (values.length === 0) return 0
  return clampIndex(index + delta, values.length)
}

function parseProfiles(raw, previousIndex) {
  var lines = String(raw || "").split("\n")
  var list = []
  var active = ""
  for (var i = 0; i < lines.length && list.length < MAX_PROFILES; i++) {
    var line = lines[i].trim()
    if (!line) continue
    var parts = line.split("\t")
    var name = cleanProfileName(parts[0])
    if (!name || list.indexOf(name) !== -1) continue
    list.push(name)
    if (parts[1] === "1") active = name
  }
  return {
    profiles: list,
    activeProfile: active,
    profileIndex: clampIndex(previousIndex || 0, list.length)
  }
}

function profileIcon(name) {
  if (name === "power-saver") return "󰌪"
  if (name === "balanced") return "󰊚"
  if (name === "performance") return "󰓅"
  return "󰂄"
}

if (typeof module !== "undefined") {
  module.exports = {
    cleanProfileName: cleanProfileName,
    clampIndex: clampIndex,
    selectProfileIndex: selectProfileIndex,
    parseProfiles: parseProfiles,
    profileIcon: profileIcon,
    MAX_PROFILES: MAX_PROFILES,
    MAX_PROFILE_NAME: MAX_PROFILE_NAME
  }
}
