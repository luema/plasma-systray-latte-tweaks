/*
 *   Copyright 2011 Marco Martin <mart@kde.org>
 *   Copyright 2020 Konrad Materka <materka@gmail.com>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU Library General Public License as
 *   published by the Free Software Foundation; either version 2, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Library General Public License for more details
 *
 *   You should have received a copy of the GNU Library General Public
 *   License along with this program; if not, write to the
 *   Free Software Foundation, Inc.,
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

import QtQuick 2.5
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.1 as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.draganddrop 2.0 as DnD
import org.kde.kirigami 2.5 as Kirigami

import "items"

MouseArea {
    id: root

    Layout.minimumWidth: vertical ? units.iconSizes.small : tasksGrid.implicitWidth + (expander.visible ? expander.implicitWidth : 0) + units.smallSpacing

    Layout.minimumHeight: vertical ? tasksGrid.implicitHeight + (expander.visible ? expander.implicitHeight : 0) + units.smallSpacing : units.smallSpacing

    Layout.preferredHeight: Layout.minimumHeight
    LayoutMirroring.enabled: !vertical && Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // The icon size to display when not using the auto-scaling setting
    readonly property int smallIconSize: units.iconSizes.smallMedium

    // Used only by AbstractItem, but it's easiest to keep it here since it
    // uses dimensions from this item to calculate the final value
    readonly property int itemSize: autoSize ? units.roundToIconSize(Math.min(Math.min(width / rowsOrColumns, height / rowsOrColumns), units.iconSizes.enormous)) : smallIconSize

    // The rest are derived properties; do not modify
    readonly property bool vertical: plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool autoSize: plasmoid.configuration.scaleIconsToFit
    readonly property int cellThickness: root.vertical ? root.width : root.height
    readonly property int rowsOrColumns: autoSize ? 1 : Math.max(1, Math.floor(cellThickness / (smallIconSize + plasmoid.configuration.iconsSpacing)))

    property alias expanded: dialog.visible
    property Item activeApplet
    property alias visibleLayout: tasksGrid
    property alias hiddenLayout: expandedRepresentation.hiddenLayout

    Plasmoid.onExpandedChanged: {
        if (!plasmoid.expanded) {
            dialog.visible = plasmoid.expanded;
        }
    }

    //! Latte Connection
    property QtObject latteBridge: null
    readonly property bool inLatte: latteBridge !== null
    readonly property bool inLatteCustomPalette: inLatte && latteBridge.applyPalette
    readonly property bool internalMainHighlightEnabled: plasmoid.configuration.internalMainHighlightEnabled

    onLatteBridgeChanged: {
        if (latteBridge) {
            latteBridge.actions.setProperty(plasmoid.id, "latteSideColoringEnabled", false);
            cItemHighlight.informLatteIndicator();
        }
    }

    onInternalMainHighlightEnabledChanged: cItemHighlight.informLatteIndicator()
    //!

    onWheel: {
        // Don't propagate unhandled wheel events
        wheel.accepted = true;
    }

    //being there forces the items to fully load, and they will be reparented in the popup one by one, this item is *never* visible
    Item {
        id: preloadedStorage
        visible: false
    }

    Connections {
        target: plasmoid
        function onUserConfiguringChanged() {
            if (plasmoid.userConfiguring) {
                dialog.visible = false
            }
        }
    }

    Connections {
        target: plasmoid.configuration

        function onExtraItemsChanged() {
            plasmoid.nativeInterface.allowedPlasmoids = plasmoid.configuration.extraItems;
        }
    }

    CurrentItemHighLight {
        id: cItemHighlight
        readonly property bool visibleAppletActivated: root.activeApplet && root.activeApplet.parent && root.activeApplet.parent.inVisibleLayout
        parent: visibleAppletActivated ? root.activeApplet.parent : root
        location: plasmoid.location

        function informLatteIndicator() {
            if (!inLatte) {
                return;
            }

            if (root.internalMainHighlightEnabled || parent !== root) {
                latteBridge.actions.setProperty(plasmoid.id, "activeIndicatorEnabled", false);
            } else if (parent) {
                latteBridge.actions.setProperty(plasmoid.id, "activeIndicatorEnabled", true);
            }
        }

        onParentChanged: cItemHighlight.informLatteIndicator()

        Connections {
            target: root
            onInLatteChanged: cItemHighlight.informLatteIndicator()
        }
    }

    DnD.DropArea {
        anchors.fill: parent

        preventStealing: true;

        /** Extracts the name of the system tray applet in the drag data if present
         * otherwise returns null*/
        function systemTrayAppletName(event) {
            if (event.mimeData.formats.indexOf("text/x-plasmoidservicename") < 0) {
                return null;
            }
            var plasmoidId = event.mimeData.getDataAsByteArray("text/x-plasmoidservicename");

            if (!plasmoid.nativeInterface.isSystemTrayApplet(plasmoidId)) {
                return null;
            }
            return plasmoidId;
        }

        onDragEnter: {
            if (!systemTrayAppletName(event)) {
                event.ignore();
            }
        }

        onDrop: {
            var plasmoidId = systemTrayAppletName(event);
            if (!plasmoidId) {
                event.ignore();
                return;
            }

            if (plasmoid.configuration.extraItems.indexOf(plasmoidId) < 0) {
                var extraItems = plasmoid.configuration.extraItems;
                extraItems.push(plasmoidId);
                plasmoid.configuration.extraItems = extraItems;
            }
        }
    }

    //Main Layout
    GridLayout {
        id: mainLayout
        rowSpacing: 0
        columnSpacing: 0
        anchors.fill: parent
        flow: vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight

        GridView {
            id: tasksGrid
            readonly property int smallSizeCellLength: root.cellThickness >= root.smallIconSize ? root.smallIconSize + plasmoid.configuration.iconsSpacing
                                                                                               : root.smallIconSize
            readonly property int autoSizeCellLength: (root.cellThickness / root.rowsOrColumns)
            readonly property int totalLength: root.vertical ? cellHeight * Math.round(count / root.rowsOrColumns)
                                                             : cellWidth * Math.round(count / root.rowsOrColumns)

            Layout.alignment: Qt.AlignCenter

            interactive: false //disable features we don't need
            flow: vertical ? GridView.LeftToRight : GridView.TopToBottom

            implicitHeight: root.vertical ? totalLength : root.height
            implicitWidth: !root.vertical ? totalLength : root.width

            cellHeight: root.vertical && !root.autoSize ? smallSizeCellLength : autoSizeCellLength + (root.vertical ? plasmoid.configuration.iconsSpacing : 0)
            cellWidth:  !root.vertical && !root.autoSize ? smallSizeCellLength : autoSizeCellLength + (!root.vertical ? plasmoid.configuration.iconsSpacing : 0)

            model: PlasmaCore.SortFilterModel {
                sourceModel: plasmoid.nativeInterface.systemTrayModel
                filterRole: "effectiveStatus"
                filterCallback: function(source_row, value) {
                    return value === PlasmaCore.Types.ActiveStatus
                }
            }

            delegate: ItemLoader {}

            add: Transition {
                enabled: root.itemSize > 0

                NumberAnimation {
                    property: "scale"
                    from: 0
                    to: 1
                    easing.type: Easing.InOutQuad
                    duration: units.longDuration
                }
            }

            displaced: Transition {
                //ensure scale value returns to 1.0
                //https://doc.qt.io/qt-5/qml-qtquick-viewtransition.html#handling-interrupted-animations
                NumberAnimation {
                    property: "scale"
                    to: 1
                    easing.type: Easing.InOutQuad
                    duration: units.longDuration
                }
            }

            move: Transition {
                NumberAnimation {
                    properties: "x,y"
                    easing.type: Easing.InOutQuad
                    duration: units.longDuration
                }
            }
        }

        ExpanderArrow {
            id: expander
            Layout.fillWidth: vertical
            Layout.fillHeight: !vertical
        }
    }

    //Main popup
    PlasmaCore.Dialog {
        id: dialog
        visualParent: root
        flags: Qt.WindowStaysOnTopHint
        location: plasmoid.location
        hideOnWindowDeactivate: !plasmoid.configuration.pin

        onVisibleChanged: {
            if (!visible) {
                plasmoid.status = PlasmaCore.Types.PassiveStatus;
                if (root.activeApplet) {
                    root.activeApplet.expanded = false;
                }
            } else {
                plasmoid.status = PlasmaCore.Types.RequiresAttentionStatus;
            }
            plasmoid.expanded = visible;
        }
        mainItem: ExpandedRepresentation {
            id: expandedRepresentation

            Keys.onEscapePressed: {
                root.expanded = false;
            }

            activeApplet: root.activeApplet

            LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
            LayoutMirroring.childrenInherit: true
        }
    }
}
