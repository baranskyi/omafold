import QtQuick
import Quickshell.Io
import qs.Ui
import "DrawerModel.js" as DrawerModel

BarWidget {
  id: root

  moduleName: "io.github.baranskyi.omafold"

  property var ownerSlot: null
  property var slotRow: null
  property var hiddenSlots: []
  property var alwaysHiddenSlots: []
  property var runningAnimations: []
  property bool expanded: false
  property bool pinnedOpen: false
  property bool revealAlwaysHidden: false
  property bool suppressHoverUntilExit: false
  property double lastWantedAt: 0
  property double lastInteractionAt: 0
  property bool menuOpen: false
  readonly property bool opened: menuOpen
  property var backdrop: null

  readonly property var excludedIds: DrawerModel.normalizeList(setting("exclude", ""))
  readonly property var alwaysHiddenIds: DrawerModel.normalizeList(setting("alwaysHidden", ""))
  readonly property string collapseSide: DrawerModel.effectiveSide(
    setting("collapseSide", "auto"), ownerSlot ? ownerSlot.region : "")
  readonly property bool revealOnHover: DrawerModel.booleanValue(setting("revealOnHover", true), true)
  readonly property bool revealOnClick: DrawerModel.booleanValue(setting("revealOnClick", true), true)
  readonly property int animationDuration: DrawerModel.boundedInteger(
    setting("animationDuration", 220), 220, 0, 1000)
  readonly property int collapseDelay: DrawerModel.boundedInteger(
    setting("collapseDelay", 240), 240, 0, 3000)
  readonly property int autoCollapse: DrawerModel.boundedInteger(setting("autoCollapse", 0), 0, 0, 600)
  readonly property bool scrollReveal: DrawerModel.booleanValue(setting("scrollReveal", false), false)
  readonly property string arrowStyle: DrawerModel.normalizedArrowStyle(setting("arrowStyle", "chevron"))
  readonly property var arrow: DrawerModel.arrowGlyph(arrowStyle, vertical)
  readonly property bool drawerBackground: DrawerModel.booleanValue(setting("drawerBackground", true), true)
  readonly property real drawerBackgroundOpacity: DrawerModel.boundedInteger(
    setting("drawerBackgroundOpacity", 100), 100, 10, 100) / 100
  readonly property real backdropPadding: 6
  // `bar` is typed QtObject; for third-party widgets it is a PluginBarApi,
  // whose `shell` facade exposes updateEntryInline for the widget's own entry.
  // qmllint disable missing-property
  readonly property bool canSave: !!(bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
  // qmllint enable missing-property
  readonly property var menuRows: menuOpen ? collapsibleRows() : []
  readonly property int controlledCount: hiddenSlots.length + alwaysHiddenSlots.length
  readonly property real collapsedRotation: vertical
    ? (collapseSide === "before" ? 90 : 270)
    : (collapseSide === "before" ? 0 : 180)
  // Poll quickly only while something can change under the pointer. At rest
  // the hover and popout signals below wake the controller immediately.
  readonly property bool busy: (expanded && !pinnedOpen && !menuOpen) || runningAnimations.length > 0
    || suppressHoverUntilExit || opener.tooltipHovered

  visible: ownerSlot === null || controlledCount > 0
  implicitWidth: visible ? opener.implicitWidth : 0
  implicitHeight: visible ? opener.implicitHeight : 0

  function indexOfSlot(list, slot) {
    for (var i = 0; i < list.length; i++) if (list[i] === slot) return i
    return -1
  }

  function sameSlots(first, second) {
    if (first.length !== second.length) return false
    for (var i = 0; i < first.length; i++) if (first[i] !== second[i]) return false
    return true
  }

  function combinedSlots(first, second) {
    var result = first.slice()
    for (var i = 0; i < second.length; i++)
      if (indexOfSlot(result, second[i]) === -1) result.push(second[i])
    return result
  }

  // The bar hands third-party widgets a narrow API, so the controller finds
  // its own module slot by walking up the item tree. The slot's parent is the
  // row (or column) that holds this bar section's other widget slots.
  function findOwner() {
    var node = root.parent
    while (node) {
      // qmllint disable missing-property
      if (node.moduleName === root.moduleName && node.activeItem === root) {
      // qmllint enable missing-property
        ownerSlot = node
        slotRow = node.parent
        return true
      }
      node = node.parent
    }
    ownerSlot = null
    slotRow = null
    return false
  }

  // The bar anchors its center section to the screen center while the side
  // sections stay pinned to the edges, so an expanded drawer grows over the
  // center widgets. Slots are transparent, which makes both unreadable. The
  // backdrop is a Rectangle parented to the section's row: inside the row it
  // sits behind the slots at z -1, and the whole row already draws above the
  // center section, so the revealed widgets get a solid panel under them.
  function ensureBackdrop() {
    if (backdrop || !slotRow || !ownerSlot || !drawerBackground) return

    var node = backdropComponent.createObject(slotRow)
    if (!node) return
    backdrop = node
    node.destroyed.connect(function() { if (root.backdrop === node) root.backdrop = null })

    var pad = backdropPadding
    if (root.vertical) {
      node.x = Qt.binding(function() { return 0 })
      node.width = Qt.binding(function() { return root.slotRow ? root.slotRow.width : 0 })
      node.y = Qt.binding(function() {
        if (!root.ownerSlot) return 0
        return root.collapseSide === "before" ? -pad : root.ownerSlot.y - pad
      })
      node.height = Qt.binding(function() {
        if (!root.slotRow || !root.ownerSlot) return 0
        return root.collapseSide === "before"
          ? root.ownerSlot.y + root.ownerSlot.height + pad
          : root.slotRow.height - root.ownerSlot.y + pad
      })
    } else {
      node.y = Qt.binding(function() { return 0 })
      node.height = Qt.binding(function() { return root.slotRow ? root.slotRow.height : 0 })
      node.x = Qt.binding(function() {
        if (!root.ownerSlot) return 0
        return root.collapseSide === "before" ? -pad : root.ownerSlot.x - pad
      })
      node.width = Qt.binding(function() {
        if (!root.slotRow || !root.ownerSlot) return 0
        return root.collapseSide === "before"
          ? root.ownerSlot.x + root.ownerSlot.width + pad
          : root.slotRow.width - root.ownerSlot.x + pad
      })
    }

    // Opacity, not visibility, so the panel fades with the reveal animation
    // and a zero-size Rectangle never intercepts pointer events anyway.
    node.opacity = Qt.binding(function() {
      return root.drawerBackground && (root.expanded || root.runningAnimations.length > 0)
        ? root.drawerBackgroundOpacity
        : 0
    })
  }

  function classifiedSlots() {
    var result = { hidden: [], alwaysHidden: [] }
    if (!slotRow || !slotRow.children) return result

    var ownerIndex = indexOfSlot(slotRow.children, ownerSlot)
    if (ownerIndex === -1) return result

    for (var i = 0; i < slotRow.children.length; i++) {
      var child = slotRow.children[i]
      if (!child || child === ownerSlot) continue
      var id = String(child.moduleName || "")
      var group = DrawerModel.groupFor(
        i, ownerIndex, id, collapseSide, excludedIds, alwaysHiddenIds)
      if (group === "hidden") result.hidden.push(child)
      else if (group === "always-hidden") result.alwaysHidden.push(child)
    }
    return result
  }

  function animationIndex(slot) {
    for (var i = 0; i < runningAnimations.length; i++)
      if (runningAnimations[i].slot === slot) return i
    return -1
  }

  function stopAnimation(slot) {
    var index = animationIndex(slot)
    if (index === -1) return
    var record = runningAnimations[index]
    var next = runningAnimations.slice()
    next.splice(index, 1)
    runningAnimations = next
    if (record.animation) {
      record.animation.stop()
      record.animation.destroy()
    }
  }

  function restoreSlot(slot) {
    if (!slot) return
    stopAnimation(slot)
    if (root.vertical)
      slot.height = Qt.binding(function() { return slot.implicitHeight })
    else
      slot.width = Qt.binding(function() { return slot.implicitWidth })
    slot.opacity = 1
    slot.clip = false
  }

  function setSlotInstant(slot, open) {
    if (!slot) return
    stopAnimation(slot)
    if (root.vertical) {
      if (open) slot.height = Qt.binding(function() { return slot.implicitHeight })
      else slot.height = 0
    } else {
      if (open) slot.width = Qt.binding(function() { return slot.implicitWidth })
      else slot.width = 0
    }
    slot.opacity = open ? 1 : 0
    // Clipping a collapsed slot also stops pointer delivery to any child that
    // does not follow the slot's size, so hidden widgets cannot catch clicks.
    slot.clip = !open
  }

  function slotExtent(slot) {
    return root.vertical ? slot.height : slot.width
  }

  function slotShouldOpen(slot) {
    if (indexOfSlot(hiddenSlots, slot) !== -1) return expanded
    if (indexOfSlot(alwaysHiddenSlots, slot) !== -1)
      return expanded && revealAlwaysHidden
    return true
  }

  function finishAnimation(slot, animation) {
    var index = animationIndex(slot)
    if (index === -1 || runningAnimations[index].animation !== animation) return
    var next = runningAnimations.slice()
    next.splice(index, 1)
    runningAnimations = next
    setSlotInstant(slot, slotShouldOpen(slot))
    animation.destroy()
  }

  function animateSlot(slot, open) {
    if (!slot) return
    stopAnimation(slot)

    var extent = slotExtent(slot)
    var targetExtent = open
      ? (root.vertical ? slot.implicitHeight : slot.implicitWidth)
      : 0
    if (animationDuration === 0 || Math.abs(extent - targetExtent) < 0.5) {
      setSlotInstant(slot, open)
      return
    }

    slot.clip = true
    var animation = transitionComponent.createObject(root, {
      targetSlot: slot,
      axis: root.vertical ? "height" : "width",
      extentFrom: extent,
      extentTo: targetExtent,
      opacityFrom: slot.opacity,
      opacityTo: open ? 1 : 0,
      transitionDuration: animationDuration
    })
    if (!animation) {
      setSlotInstant(slot, open)
      return
    }

    var next = runningAnimations.slice()
    next.push({ slot: slot, animation: animation })
    runningAnimations = next
    animation.finished.connect(function() { root.finishAnimation(slot, animation) })
    animation.start()
  }

  function restoreControlledSlots() {
    var slots = combinedSlots(hiddenSlots, alwaysHiddenSlots)
    for (var i = 0; i < slots.length; i++) restoreSlot(slots[i])
  }

  function refreshSlots() {
    if ((!ownerSlot || !slotRow) && !findOwner()) return
    ensureBackdrop()
    var groups = classifiedSlots()
    if (sameSlots(hiddenSlots, groups.hidden)
        && sameSlots(alwaysHiddenSlots, groups.alwaysHidden)) return

    restoreControlledSlots()
    hiddenSlots = groups.hidden
    alwaysHiddenSlots = groups.alwaysHidden

    for (var i = 0; i < hiddenSlots.length; i++)
      setSlotInstant(hiddenSlots[i], expanded)
    for (var j = 0; j < alwaysHiddenSlots.length; j++)
      setSlotInstant(alwaysHiddenSlots[j], expanded && revealAlwaysHidden)
  }

  function slotKeepsDrawerOpen(slot) {
    if (!slot) return false
    var item = slot.activeItem
    if (slot.panelOpen === true || (item && item.opened === true)) return true
    // A collapsed slot is zero-sized and clipped, so the pointer cannot be
    // over it; skipping the tree walk keeps the idle poll cheap.
    if (slotExtent(slot) < 0.5) return false
    if (slot.hovered === true) return true
    return itemTreeHovered(item, 5, { count: 0 })
  }

  function itemTreeHovered(item, depth, budget) {
    if (!item || depth < 0 || budget.count >= 80) return false
    budget.count++
    if (item.tooltipHovered === true || item.containsMouse === true) return true

    var children = item.children
    if (!children) return false
    for (var i = 0; i < children.length; i++)
      if (itemTreeHovered(children[i], depth - 1, budget)) return true
    return false
  }

  // Every widget the drawer governs, in bar order, for the options menu. It
  // reads the same row the drawer classifies, so the two can never disagree.
  function collapsibleRows() {
    var rows = []
    if (!slotRow || !slotRow.children) return rows
    var ownerIndex = indexOfSlot(slotRow.children, ownerSlot)
    for (var i = 0; i < slotRow.children.length; i++) {
      var child = slotRow.children[i]
      var id = child ? String(child.moduleName || "") : ""
      if (!id || !DrawerModel.onCollapsibleSide(i, ownerIndex, collapseSide)) continue
      var meta = child.registryMetadata
      rows.push({
        id: id,
        name: meta && meta.displayName ? String(meta.displayName) : id,
        choice: DrawerModel.membershipOf(id, excludedIds, alwaysHiddenIds)
      })
    }
    return rows
  }

  // The menu counts as interaction too: it keeps the drawer open so every
  // change shows up in the bar while the menu is still on screen.
  function interactionActive() {
    if (menuOpen || opener.tooltipHovered) return true
    var slots = combinedSlots(hiddenSlots, alwaysHiddenSlots)
    for (var i = 0; i < slots.length; i++)
      if (slotKeepsDrawerOpen(slots[i])) return true
    return false
  }

  function wantsExpansion() {
    if (pinnedOpen || menuOpen) return true
    var slots = combinedSlots(hiddenSlots, alwaysHiddenSlots)
    for (var i = 0; i < slots.length; i++)
      if (slotKeepsDrawerOpen(slots[i])) return true

    if (suppressHoverUntilExit) {
      if (!opener.tooltipHovered) suppressHoverUntilExit = false
      else return false
    }
    return revealOnHover && opener.tooltipHovered
  }

  function setExpanded(open) {
    if (expanded === open) return
    expanded = open
    if (!open) revealAlwaysHidden = false

    for (var i = 0; i < hiddenSlots.length; i++) animateSlot(hiddenSlots[i], open)
    for (var j = 0; j < alwaysHiddenSlots.length; j++)
      animateSlot(alwaysHiddenSlots[j], open && revealAlwaysHidden)
  }

  function setAlwaysHiddenRevealed(open) {
    if (revealAlwaysHidden === open) return
    revealAlwaysHidden = open
    for (var i = 0; i < alwaysHiddenSlots.length; i++)
      animateSlot(alwaysHiddenSlots[i], expanded && open)
  }

  function togglePinned() {
    if (!revealOnClick) return
    if (!pinnedOpen) {
      suppressHoverUntilExit = false
      pinnedOpen = true
      setExpanded(true)
      return
    }

    pinnedOpen = false
    setAlwaysHiddenRevealed(false)
    suppressHoverUntilExit = opener.tooltipHovered
    setExpanded(false)
  }

  function toggleEverything() {
    if (!revealAlwaysHidden) {
      suppressHoverUntilExit = false
      pinnedOpen = true
      setExpanded(true)
      setAlwaysHiddenRevealed(true)
      return
    }

    pinnedOpen = false
    setAlwaysHiddenRevealed(false)
    suppressHoverUntilExit = opener.tooltipHovered
    setExpanded(false)
  }

  function showRegular() {
    suppressHoverUntilExit = false
    pinnedOpen = true
    setExpanded(true)
  }

  function hideDrawer() {
    pinnedOpen = false
    setAlwaysHiddenRevealed(false)
    suppressHoverUntilExit = opener.tooltipHovered
    setExpanded(false)
  }

  function toggleFromIpc() {
    if (expanded || pinnedOpen) hideDrawer()
    else showRegular()
  }

  function showEverything() {
    suppressHoverUntilExit = false
    pinnedOpen = true
    setExpanded(true)
    setAlwaysHiddenRevealed(true)
  }

  // The bar calls close() when another popout takes over.
  function close() { menuOpen = false }
  function toggleMenu() { menuOpen = !menuOpen }

  // Quick actions finish with the menu closed: while it is open it holds the
  // drawer open, which would undo a collapse at the next poll.
  function menuToggleEverything() {
    menuOpen = false
    toggleEverything()
  }

  function menuTogglePinned() {
    menuOpen = false
    if (pinnedOpen) hideDrawer()
    else showRegular()
  }

  // updateEntryInline replaces the whole entry, so the patch is merged into
  // the current settings first. Omarchy Shell writes shell.json and pushes
  // the result back into `settings` on every bar.
  function saveSettings(patch) {
    if (!canSave) return false
    var next = Object.assign({}, settings || {}, patch)
    settings = next
    // qmllint disable missing-property
    return bar.shell.updateEntryInline(moduleName, next)
    // qmllint enable missing-property
  }

  function setMembership(id, choice) {
    return saveSettings(DrawerModel.membershipPatch(id, choice, excludedIds, alwaysHiddenIds))
  }

  // Widgets that currently draw nothing (a disconnected VPN, no pending
  // update) are still managed, but they are not worth announcing.
  function availableCount(slots) {
    var count = 0
    for (var i = 0; i < slots.length; i++) {
      var item = slots[i] ? slots[i].activeItem : null
      if (item && item.visible !== false) count++
    }
    return count
  }

  function tooltipText() {
    return DrawerModel.tooltipText({
      expanded: expanded,
      pinned: pinnedOpen,
      revealAlwaysHidden: revealAlwaysHidden,
      clickable: revealOnClick,
      hiddenCount: availableCount(hiddenSlots),
      alwaysHiddenCount: availableCount(alwaysHiddenSlots)
    })
  }

  function poll() {
    refreshSlots()

    if (pinnedOpen && autoCollapse > 0) {
      var now = Date.now()
      if (interactionActive()) lastInteractionAt = now
      else if (DrawerModel.shouldAutoCollapse(now, lastInteractionAt, autoCollapse)) {
        hideDrawer()
        return
      }
    }

    if (wantsExpansion()) {
      lastWantedAt = Date.now()
      setExpanded(true)
      return
    }

    if (expanded && Date.now() - lastWantedAt >= collapseDelay) setExpanded(false)
  }

  Component.onCompleted: Qt.callLater(poll)
  Component.onDestruction: restoreControlledSlots()

  // Settings now change from the options menu while the drawer is open, so a
  // change keeps the pinned and revealed state. refreshSlots() regroups the
  // widgets in one step when the lists or the side changed.
  onSettingsChanged: Qt.callLater(poll)
  onPinnedOpenChanged: if (pinnedOpen) lastInteractionAt = Date.now()

  // Keeps running while the controller hides itself, so it reappears as soon
  // as a widget lands on the collapsible side again.
  Timer {
    interval: root.busy ? 40 : 250
    repeat: true
    running: true
    onTriggered: root.poll()
  }

  // A panel opened from the keyboard or over IPC must reveal its collapsed
  // owner right away instead of waiting for the next idle poll.
  Connections {
    target: root.bar
    ignoreUnknownSignals: true
    function onActivePopoutChanged() { root.poll() }
  }

  IpcHandler {
    target: root.moduleName

    function show(): void { root.broadcast("showRegular") }
    function hide(): void { root.broadcast("hideDrawer") }
    function toggle(): void { root.broadcast("toggleFromIpc") }
    function showAll(): void { root.broadcast("showEverything") }
    // One menu at a time: it opens on the bar that owns this handler rather
    // than on every monitor at once.
    function options(): void { root.toggleMenu() }
  }

  BarIconButton {
    id: opener
    anchors.fill: parent
    bar: root.bar
    text: root.arrow.text
    active: root.pinnedOpen || root.revealAlwaysHidden
    tooltipText: root.tooltipText()
    textRotation: !root.arrow.rotates ? 0
      : root.expanded ? (root.collapsedRotation + 180) % 360
      : root.collapsedRotation

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.toggleMenu()
      else if (buttonCode === Qt.MiddleButton) root.toggleEverything()
      else if (buttonCode === Qt.LeftButton) root.togglePinned()
    }
    onWheelMoved: function(delta) {
      if (!root.scrollReveal || delta === 0) return
      if (delta > 0) root.showRegular()
      else root.hideDrawer()
    }
    onTooltipHoveredChanged: root.poll()

    Behavior on textRotation {
      NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
    }
  }

  OptionsMenu { drawer: root }

  Component {
    id: backdropComponent

    Rectangle {
      // qmllint disable missing-property
      color: root.bar.background
      // qmllint enable missing-property
      radius: 8
      z: -1

      Behavior on opacity {
        NumberAnimation {
          duration: root.animationDuration > 0 ? root.animationDuration : 140
          easing.type: Easing.OutCubic
        }
      }
    }
  }

  Component {
    id: transitionComponent

    ParallelAnimation {
      id: transition
      property var targetSlot: null
      property string axis: "width"
      property real extentFrom: 0
      property real extentTo: 0
      property real opacityFrom: 0
      property real opacityTo: 0
      property int transitionDuration: 220

      NumberAnimation {
        target: transition.targetSlot
        property: transition.axis
        from: transition.extentFrom
        to: transition.extentTo
        duration: transition.transitionDuration
        easing.type: Easing.OutCubic
      }

      NumberAnimation {
        target: transition.targetSlot
        property: "opacity"
        from: transition.opacityFrom
        to: transition.opacityTo
        duration: transition.transitionDuration
        easing.type: Easing.OutCubic
      }
    }
  }
}
