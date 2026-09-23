function normalizeList(value) {
  var values = []
  if (value === undefined || value === null) return values

  if (typeof value === "string") {
    values = value.split(/[,;\n]/)
  } else {
    // shell.json arrays can cross the QVariant/QML boundary without becoming
    // native JavaScript Arrays. Indexed access and length remain available.
    var length = Number(value.length)
    if (!isNaN(length)) {
      for (var i = 0; i < length; i++) values.push(value[i])
    }
  }

  var result = []
  for (var j = 0; j < values.length; j++) {
    var id = String(values[j] === undefined || values[j] === null ? "" : values[j]).trim()
    if (id !== "" && result.indexOf(id) === -1) result.push(id)
  }
  return result
}

function normalizedSide(value) {
  var side = String(value === undefined || value === null ? "" : value).toLowerCase().trim()
  return side === "before" || side === "after" ? side : "auto"
}

function effectiveSide(value, region) {
  var side = normalizedSide(value)
  if (side !== "auto") return side
  // The drawer grows away from the edge its section is anchored to, so the
  // controller stays under the pointer while the hidden widgets slide out.
  return String(region || "") === "left" ? "after" : "before"
}

function booleanValue(value, fallback) {
  if (value === undefined || value === null || value === "") return fallback
  if (typeof value === "string") {
    var normalized = value.toLowerCase().trim()
    if (normalized === "false" || normalized === "off" || normalized === "0") return false
    if (normalized === "true" || normalized === "on" || normalized === "1") return true
  }
  return value === true
}

function boundedInteger(value, fallback, minimum, maximum) {
  var number = Number(value)
  if (!isFinite(number)) number = fallback
  return Math.max(minimum, Math.min(maximum, Math.round(number)))
}

function onCollapsibleSide(index, ownerIndex, side) {
  if (ownerIndex < 0 || index === ownerIndex) return false
  return effectiveSide(side, "") === "after" ? index > ownerIndex : index < ownerIndex
}

function groupFor(index, ownerIndex, id, side, excludedIds, alwaysHiddenIds) {
  if (!id || !onCollapsibleSide(index, ownerIndex, side)) return "shown"
  if (excludedIds.indexOf(id) !== -1) return "shown"
  if (alwaysHiddenIds.indexOf(id) !== -1) return "always-hidden"
  return "hidden"
}

// Where the menu files a widget on the collapsible side. `exclude` wins over
// `alwaysHidden`, exactly as groupFor() resolves the two lists.
function membershipOf(id, excludedIds, alwaysHiddenIds) {
  if (excludedIds.indexOf(id) !== -1) return "visible"
  if (alwaysHiddenIds.indexOf(id) !== -1) return "always-hidden"
  return "hidden"
}

function membershipPatch(id, choice, excludedIds, alwaysHiddenIds) {
  var exclude = excludedIds.filter(function(other) { return other !== id })
  var alwaysHidden = alwaysHiddenIds.filter(function(other) { return other !== id })
  if (choice === "visible") exclude.push(id)
  else if (choice === "always-hidden") alwaysHidden.push(id)
  return { exclude: exclude.join(", "), alwaysHidden: alwaysHidden.join(", ") }
}

// Menu presets highlight only on an exact match, so a hand-tuned value from
// `omarchy bar set` never pretends to be the nearest preset.
function presetKey(value, presets) {
  var number = Number(value)
  for (var i = 0; i < presets.length; i++)
    if (Number(presets[i]) === number) return String(presets[i])
  return ""
}

function normalizedArrowStyle(value) {
  var style = String(value === undefined || value === null ? "" : value).toLowerCase().trim()
  return style === "dots" || style === "ellipsis" ? style : "chevron"
}

// Dots and ellipsis are symmetric, so only the chevron turns to show which
// way the drawer opens. On a vertical bar the two static glyphs swap, so each
// keeps the same orientation relative to the bar.
function arrowGlyph(style, vertical) {
  var normalized = normalizedArrowStyle(style)
  if (normalized === "dots") return { text: vertical ? "\uf141" : "\uf142", rotates: false }
  if (normalized === "ellipsis") return { text: vertical ? "\uf142" : "\uf141", rotates: false }
  return { text: "\uf053", rotates: true }
}

function shouldAutoCollapse(now, lastInteractionAt, seconds) {
  if (!(seconds > 0)) return false
  return now - lastInteractionAt >= seconds * 1000
}

function countLabel(count, noun) {
  return count + " " + noun + (count === 1 ? "" : "s")
}

function tooltipText(state) {
  if (state.revealAlwaysHidden) return "All items shown · middle-click to collapse"
  if (state.pinned) return state.clickable ? "Pinned open · click to collapse" : "Pinned open"
  if (state.expanded) return ""

  var parts = []
  if (state.hiddenCount > 0)
    parts.push((state.clickable ? "Click to show " : "") + countLabel(state.hiddenCount, "hidden item"))
  if (state.alwaysHiddenCount > 0)
    parts.push("middle-click for " + countLabel(state.alwaysHiddenCount, "always-hidden item"))
  if (parts.length === 0) parts.push("Nothing hidden right now")
  parts.push("right-click for options")

  var text = parts.join(" · ")
  return text.charAt(0).toUpperCase() + text.slice(1)
}
