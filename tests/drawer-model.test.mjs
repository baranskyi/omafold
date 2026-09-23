import assert from "node:assert/strict"
import fs from "node:fs"
import path from "node:path"
import test from "node:test"
import vm from "node:vm"
import { fileURLToPath } from "node:url"

const testDir = path.dirname(fileURLToPath(import.meta.url))
const source = fs.readFileSync(path.join(testDir, "..", "DrawerModel.js"), "utf8")
const model = {}
vm.createContext(model)
vm.runInContext(source, model, { filename: "DrawerModel.js" })

function plain(value) {
  return JSON.parse(JSON.stringify(value))
}

test("normalizes comma-separated and QVariant-like lists", () => {
  assert.deepEqual(plain(model.normalizeList(" alpha, beta;alpha\ngamma ")), [
    "alpha",
    "beta",
    "gamma"
  ])
  assert.deepEqual(plain(model.normalizeList({ 0: "one", 1: "two", length: 2 })), [
    "one",
    "two"
  ])
})

test("after mode hides widgets that follow the controller", () => {
  assert.equal(model.groupFor(3, 2, "plugin.clock", "after", [], []), "hidden")
  assert.equal(model.groupFor(1, 2, "plugin.network", "after", [], []), "shown")
})

test("before mode hides widgets that precede the controller", () => {
  assert.equal(model.groupFor(1, 2, "plugin.network", "before", [], []), "hidden")
  assert.equal(model.groupFor(3, 2, "plugin.clock", "before", [], []), "shown")
})

test("excluded widgets remain visible on the collapsible side", () => {
  assert.equal(
    model.groupFor(3, 2, "plugin.network", "after", ["plugin.network"], []),
    "shown"
  )
})

test("always-hidden widgets form the deep drawer", () => {
  assert.equal(
    model.groupFor(3, 2, "plugin.vpn", "after", [], ["plugin.vpn"]),
    "always-hidden"
  )
})

test("auto side grows the drawer away from the section's anchored edge", () => {
  assert.equal(model.effectiveSide("auto", "right"), "before")
  assert.equal(model.effectiveSide("auto", "center"), "before")
  assert.equal(model.effectiveSide("auto", "left"), "after")
  assert.equal(model.effectiveSide(undefined, "left"), "after")
  assert.equal(model.effectiveSide("before", "left"), "before")
  assert.equal(model.effectiveSide(" AFTER ", "right"), "after")
})

test("invalid sides safely fall back to auto", () => {
  assert.equal(model.normalizedSide("sideways"), "auto")
  assert.equal(model.normalizedSide(null), "auto")
  assert.equal(model.effectiveSide("sideways", "left"), "after")
  assert.equal(model.groupFor(1, 2, "plugin.clock", "sideways", [], []), "hidden")
})

test("excluded wins over always-hidden and the visible side wins over both lists", () => {
  assert.equal(
    model.groupFor(1, 2, "plugin.vpn", "before", ["plugin.vpn"], ["plugin.vpn"]),
    "shown"
  )
  assert.equal(model.groupFor(3, 2, "plugin.vpn", "before", [], ["plugin.vpn"]), "shown")
})

test("the controller and unnamed children are never managed", () => {
  assert.equal(model.groupFor(2, 2, "io.github.baranskyi.omafold", "before", [], []), "shown")
  assert.equal(model.groupFor(1, 2, "", "before", [], []), "shown")
  assert.equal(model.groupFor(1, -1, "plugin.clock", "before", [], []), "shown")
})

test("tooltip describes what each mouse button does", () => {
  const collapsed = { expanded: false, pinned: false, revealAlwaysHidden: false, clickable: true }
  assert.equal(
    model.tooltipText({ ...collapsed, hiddenCount: 3, alwaysHiddenCount: 1 }),
    "Click to show 3 hidden items · middle-click for 1 always-hidden item · right-click for options"
  )
  assert.equal(
    model.tooltipText({ ...collapsed, clickable: false, hiddenCount: 1, alwaysHiddenCount: 0 }),
    "1 hidden item · right-click for options"
  )
  assert.equal(
    model.tooltipText({ ...collapsed, hiddenCount: 0, alwaysHiddenCount: 2 }),
    "Middle-click for 2 always-hidden items · right-click for options"
  )
  assert.equal(
    model.tooltipText({ ...collapsed, hiddenCount: 0, alwaysHiddenCount: 0 }),
    "Nothing hidden right now · right-click for options"
  )
})

test("tooltip reports pinned and fully revealed states", () => {
  const base = { hiddenCount: 2, alwaysHiddenCount: 1, clickable: true }
  assert.equal(model.tooltipText({ ...base, expanded: true }), "")
  assert.equal(
    model.tooltipText({ ...base, expanded: true, pinned: true }),
    "Pinned open · click to collapse"
  )
  assert.equal(
    model.tooltipText({ ...base, expanded: true, pinned: true, clickable: false }),
    "Pinned open"
  )
  assert.equal(
    model.tooltipText({ ...base, expanded: true, pinned: true, revealAlwaysHidden: true }),
    "All items shown · middle-click to collapse"
  )
})

test("the collapsible side excludes the controller and follows the chosen side", () => {
  assert.equal(model.onCollapsibleSide(1, 2, "before"), true)
  assert.equal(model.onCollapsibleSide(3, 2, "before"), false)
  assert.equal(model.onCollapsibleSide(3, 2, "after"), true)
  assert.equal(model.onCollapsibleSide(2, 2, "before"), false)
  assert.equal(model.onCollapsibleSide(1, -1, "before"), false)
})

test("membership mirrors how the drawer resolves the two lists", () => {
  assert.equal(model.membershipOf("a", [], []), "hidden")
  assert.equal(model.membershipOf("a", ["a"], []), "visible")
  assert.equal(model.membershipOf("a", [], ["a"]), "always-hidden")
  assert.equal(model.membershipOf("a", ["a"], ["a"]), "visible")
})

test("membership patches move one widget and keep the others in order", () => {
  const excluded = ["omarchy.tray", "a"]
  const alwaysHidden = ["b", "c"]
  assert.deepEqual(plain(model.membershipPatch("a", "always-hidden", excluded, alwaysHidden)), {
    exclude: "omarchy.tray",
    alwaysHidden: "b, c, a"
  })
  assert.deepEqual(plain(model.membershipPatch("b", "visible", excluded, alwaysHidden)), {
    exclude: "omarchy.tray, a, b",
    alwaysHidden: "c"
  })
  assert.deepEqual(plain(model.membershipPatch("c", "hidden", excluded, alwaysHidden)), {
    exclude: "omarchy.tray, a",
    alwaysHidden: "b"
  })
  assert.deepEqual(plain(model.membershipPatch("new", "hidden", excluded, alwaysHidden)), {
    exclude: "omarchy.tray, a",
    alwaysHidden: "b, c"
  })
  // A widget listed in both lists ends up only where it was sent.
  assert.deepEqual(plain(model.membershipPatch("x", "always-hidden", ["x"], ["x"])), {
    exclude: "",
    alwaysHidden: "x"
  })
})

test("presets highlight only exact values", () => {
  const presets = [0, 120, 220, 400]
  assert.equal(model.presetKey(220, presets), "220")
  assert.equal(model.presetKey("0", presets), "0")
  assert.equal(model.presetKey(260, presets), "")
  assert.equal(model.presetKey("bad", presets), "")
})

test("arrow styles pick a glyph and only the chevron rotates", () => {
  assert.deepEqual(plain(model.arrowGlyph("chevron", false)), { text: "\uf053", rotates: true })
  assert.deepEqual(plain(model.arrowGlyph("dots", false)), { text: "\uf142", rotates: false })
  assert.deepEqual(plain(model.arrowGlyph("dots", true)), { text: "\uf141", rotates: false })
  assert.deepEqual(plain(model.arrowGlyph("ellipsis", false)), { text: "\uf141", rotates: false })
  assert.deepEqual(plain(model.arrowGlyph("ellipsis", true)), { text: "\uf142", rotates: false })
  assert.deepEqual(plain(model.arrowGlyph("sparkles", false)), { text: "\uf053", rotates: true })
  assert.equal(model.normalizedArrowStyle(" DOTS "), "dots")
})

test("auto-collapse waits for the configured quiet time and can be off", () => {
  assert.equal(model.shouldAutoCollapse(10000, 0, 10), true)
  assert.equal(model.shouldAutoCollapse(9999, 0, 10), false)
  assert.equal(model.shouldAutoCollapse(999999, 0, 0), false)
  assert.equal(model.shouldAutoCollapse(999999, 0, NaN), false)
})

test("booleans and timings accept shell-friendly values", () => {
  assert.equal(model.booleanValue("off", true), false)
  assert.equal(model.booleanValue("1", false), true)
  assert.equal(model.boundedInteger(5000, 220, 0, 1000), 1000)
  assert.equal(model.boundedInteger("bad", 220, 0, 1000), 220)
})
