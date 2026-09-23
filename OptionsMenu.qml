pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "DrawerModel.js" as DrawerModel

// Omarchy declares Style.font as a plain QtObject group, so qmllint cannot see
// its tokens (caption, bodySmall, subtitle, family) even though they exist.
// qmllint disable missing-property

// Right-click options for the controller. Quick actions only change the
// running drawer; every other control saves the widget's own shell.json entry
// through Omarchy (`bar.shell.updateEntryInline`) the moment it is picked.
PopupCard {
  id: menu

  required property var drawer

  readonly property color foreground: drawer.bar ? drawer.bar.foreground : Color.foreground
  readonly property color dimmed: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: drawer.bar ? drawer.bar.fontFamily : Style.font.family
  readonly property var animationPresets: [0, 120, 220, 400]
  readonly property var delayPresets: [0, 240, 800]
  readonly property var autoCollapsePresets: [0, 10, 30, 60]
  readonly property var membershipOptions: [
    { value: "visible", icon: "\uf06e", tooltip: "Always visible" },
    { value: "hidden", icon: "\uf070", tooltip: "Hidden" },
    { value: "always-hidden", icon: "\uf023", tooltip: "Always hidden" }
  ]

  anchorItem: drawer
  owner: drawer
  bar: drawer.bar
  open: drawer.menuOpen
  contentWidth: fittedContentWidth(Style.space(380))
  contentHeight: fittedContentHeight(menuColumn.implicitHeight)

  Flickable {
    anchors.fill: parent
    contentWidth: width
    contentHeight: menuColumn.implicitHeight
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Column {
      id: menuColumn
      width: parent.width
      spacing: Style.space(8)

      Text {
        text: "Omafold"
        color: menu.foreground
        font.family: menu.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Row {
        spacing: Style.space(6)

        Button {
          iconText: "\uf06e"
          text: menu.drawer.revealAlwaysHidden ? "Fold all" : "Show all"
          tooltipText: "Middle-click the arrow does the same"
          bordered: true
          foreground: menu.foreground
          fontFamily: menu.fontFamily
          fontSize: Style.font.bodySmall
          iconSize: Style.font.bodySmall
          onClicked: menu.drawer.menuToggleEverything()
        }

        Button {
          iconText: "\uf08d"
          text: menu.drawer.pinnedOpen ? "Collapse" : "Pin open"
          bordered: true
          foreground: menu.foreground
          fontFamily: menu.fontFamily
          fontSize: Style.font.bodySmall
          iconSize: Style.font.bodySmall
          onClicked: menu.drawer.menuTogglePinned()
        }
      }

      Text {
        visible: !menu.drawer.canSave
        width: parent.width
        text: "This Omarchy version cannot save widget settings from a menu. Use omarchy bar set instead."
        color: menu.dimmed
        font.family: menu.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      PanelSeparator { width: parent.width; foreground: menu.foreground }

      PanelSectionHeader {
        text: "WIDGETS"
        foreground: menu.foreground
        fontFamily: menu.fontFamily
      }

      Text {
        width: parent.width
        text: "\uf06e  visible     \uf070  hidden     \uf023  always hidden"
        color: menu.dimmed
        font.family: menu.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Text {
        visible: menu.drawer.menuRows.length === 0
        text: "No widgets on the collapsible side."
        color: menu.dimmed
        font.family: menu.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.italic: true
      }

      Repeater {
        model: menu.drawer.menuRows

        delegate: Item {
          id: widgetRow
          required property var modelData
          width: menuColumn.width
          implicitHeight: Math.max(nameLabel.implicitHeight, choice.implicitHeight)

          Text {
            id: nameLabel
            anchors.left: parent.left
            anchors.right: choice.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: widgetRow.modelData.name
            textFormat: Text.PlainText
            color: menu.foreground
            font.family: menu.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          // Compact icon chips: ButtonGroup has no size controls, and a list
          // of a dozen widgets needs rows much denser than a settings form.
          Row {
            id: choice
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            enabled: menu.drawer.canSave
            spacing: Style.space(3)

            Repeater {
              model: menu.membershipOptions

              delegate: Button {
                required property var modelData
                iconText: modelData.icon
                tooltipText: modelData.tooltip
                selected: widgetRow.modelData.choice === modelData.value
                bordered: true
                foreground: menu.foreground
                fontFamily: menu.fontFamily
                iconSize: Style.font.caption
                horizontalPadding: Style.space(4)
                verticalPadding: Style.space(2)
                onClicked: menu.drawer.setMembership(widgetRow.modelData.id, modelData.value)
              }
            }
          }
        }
      }

      Text {
        width: parent.width
        text: "Widgets on the other side of the arrow always stay visible. Drag them across to manage them here."
        color: menu.dimmed
        font.family: menu.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      PanelSeparator { width: parent.width; foreground: menu.foreground }

      PanelSectionHeader {
        text: "BEHAVIOUR"
        foreground: menu.foreground
        fontFamily: menu.fontFamily
      }

      Toggle {
        width: parent.width
        enabled: menu.drawer.canSave
        label: "Reveal on hover"
        description: "Open while the pointer is on the arrow."
        checked: menu.drawer.revealOnHover
        foreground: menu.foreground
        fontFamily: menu.fontFamily
        onClicked: menu.drawer.saveSettings({ revealOnHover: !menu.drawer.revealOnHover })
      }

      Toggle {
        width: parent.width
        enabled: menu.drawer.canSave
        label: "Pin on click"
        description: "A left-click keeps the drawer open."
        checked: menu.drawer.revealOnClick
        foreground: menu.foreground
        fontFamily: menu.fontFamily
        onClicked: menu.drawer.saveSettings({ revealOnClick: !menu.drawer.revealOnClick })
      }

      Toggle {
        width: parent.width
        enabled: menu.drawer.canSave
        label: "Scroll to reveal"
        description: "Scroll up on the arrow to open, down to fold."
        checked: menu.drawer.scrollReveal
        foreground: menu.foreground
        fontFamily: menu.fontFamily
        onClicked: menu.drawer.saveSettings({ scrollReveal: !menu.drawer.scrollReveal })
      }

      ChoiceRow {
        label: "Side"
        value: String(menu.drawer.setting("collapseSide", "auto")).toLowerCase().trim()
        options: [
          { value: "auto", label: "Auto", tooltip: "Away from the section's screen edge" },
          { value: "before", label: "Before" },
          { value: "after", label: "After" }
        ]
        onPicked: function(value) { menu.drawer.saveSettings({ collapseSide: value }) }
      }

      ChoiceRow {
        label: "Animation"
        value: DrawerModel.presetKey(menu.drawer.animationDuration, menu.animationPresets)
        options: [
          { value: "0", label: "Off" },
          { value: "120", label: "Fast" },
          { value: "220", label: "Normal" },
          { value: "400", label: "Slow" }
        ]
        onPicked: function(value) { menu.drawer.saveSettings({ animationDuration: Number(value) }) }
      }

      ChoiceRow {
        label: "Collapse delay"
        value: DrawerModel.presetKey(menu.drawer.collapseDelay, menu.delayPresets)
        options: [
          { value: "0", label: "Instant" },
          { value: "240", label: "Short" },
          { value: "800", label: "Long" }
        ]
        onPicked: function(value) { menu.drawer.saveSettings({ collapseDelay: Number(value) }) }
      }

      ChoiceRow {
        label: "Auto-collapse"
        value: DrawerModel.presetKey(menu.drawer.autoCollapse, menu.autoCollapsePresets)
        options: [
          { value: "0", label: "Off", tooltip: "A pinned drawer stays open" },
          { value: "10", label: "10 s" },
          { value: "30", label: "30 s" },
          { value: "60", label: "60 s" }
        ]
        onPicked: function(value) { menu.drawer.saveSettings({ autoCollapse: Number(value) }) }
      }

      ChoiceRow {
        label: "Arrow"
        value: menu.drawer.arrowStyle
        options: [
          { value: "chevron", label: "", icon: "\uf053", tooltip: "Chevron" },
          { value: "dots", label: "", icon: "\uf142", tooltip: "Dots" },
          { value: "ellipsis", label: "", icon: "\uf141", tooltip: "Ellipsis" }
        ]
        onPicked: function(value) { menu.drawer.saveSettings({ arrowStyle: value }) }
      }
    }
  }

  component ChoiceRow: Item {
    id: choiceRow

    property string label: ""
    property string value: ""
    property var options: []
    signal picked(string value)

    width: menuColumn.width
    implicitHeight: Math.max(choiceLabel.implicitHeight, choiceGroup.implicitHeight)

    Text {
      id: choiceLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: choiceRow.label
      color: menu.foreground
      font.family: menu.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    ButtonGroup {
      id: choiceGroup
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      enabled: menu.drawer.canSave
      spacing: Style.space(4)
      focusable: false
      foreground: menu.foreground
      fontFamily: menu.fontFamily
      fontSize: Style.font.bodySmall
      value: choiceRow.value
      options: choiceRow.options
      onChanged: function(value) { choiceRow.picked(value) }
    }
  }
}
