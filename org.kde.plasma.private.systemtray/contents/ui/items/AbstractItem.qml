/*
 *   Copyright 2016 Marco Martin <mart@kde.org>
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

import QtQuick 2.2
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

PlasmaCore.ToolTipArea {
    id: abstractItem

    height: effectiveItemSize + marginHints.top + marginHints.bottom
    width: labelVisible ? parent.width : effectiveItemSize + marginHints.left + marginHints.right

    property real effectiveItemSize: hidden ? root.hiddenItemSize : root.itemSize
    property string itemId
    property string category
    property alias text: label.text
    property bool hidden: parent.objectName == "hiddenTasksColumn"
    property QtObject marginHints: parent.marginHints
    property bool labelVisible: abstractItem.hidden && !root.activeApplet
    property Item iconItem
    //PlasmaCore.Types.ItemStatus
    property int status
    property QtObject model

    signal clicked(var mouse)
    signal pressed(var mouse)
    signal wheel(var wheel)
    signal contextMenu(var mouse)

    property bool forcedHidden: plasmoid.configuration.hiddenItems.indexOf(itemId) !== -1
    property bool forcedShown: plasmoid.configuration.showAllItems || plasmoid.configuration.shownItems.indexOf(itemId) !== -1

    readonly property int effectiveStatus: {
        if (status === PlasmaCore.Types.HiddenStatus) {
            return PlasmaCore.Types.HiddenStatus
        } else if (forcedShown || (!forcedHidden && status !== PlasmaCore.Types.PassiveStatus)) {
            return PlasmaCore.Types.ActiveStatus
        } else {
            return PlasmaCore.Types.PassiveStatus
        }
    }

    /* subclasses need to assign to this tiiltip properties
    mainText:
    subText:
    icon: 
    */

    location: {
        if (abstractItem.parent && abstractItem.parent.objectName === "hiddenTasksColumn") {
            if (LayoutMirroring.enabled && plasmoid.location !== PlasmaCore.Types.RightEdge) {
                return PlasmaCore.Types.LeftEdge;
            } else if (plasmoid.location !== PlasmaCore.Types.LeftEdge) {
                return PlasmaCore.Types.RightEdge;
            }
        }

        return plasmoid.location;
    }

//BEGIN CONNECTIONS

    property int creationId // used for item order tie breaking
    onEffectiveStatusChanged: updateItemVisibility(abstractItem)
    onCategoryChanged: updateItemVisibility(abstractItem)
    onTextChanged: updateItemVisibility(abstractItem)
    Component.onCompleted: {
        creationId = root.creationIdCounter++
        updateItemVisibility(abstractItem)
    }

    onContainsMouseChanged: {
        if (hidden && containsMouse) {
            root.hiddenLayout.hoveredItem = abstractItem
        }
    }

//END CONNECTIONS

    PulseAnimation {
        targetItem: iconItem
        running: (abstractItem.status === PlasmaCore.Types.NeedsAttentionStatus ||
            abstractItem.status === PlasmaCore.Types.RequiresAttentionStatus ) &&
            units.longDuration > 0
    }

    function activated() {
        activatedAnimation.start()
    }

    SequentialAnimation {
        id: activatedAnimation
        loops: 1

        ScaleAnimator {
            target: iconItem
            from: 1
            to: 0.5
            duration: units.shortDuration
            easing.type: Easing.InQuad
        }

        ScaleAnimator {
            target: iconItem
            from: 0.5
            to: 1
            duration: units.shortDuration
            easing.type: Easing.OutQuad
        }
    }

    MouseArea {
        anchors.fill: abstractItem
        hoverEnabled: true
        drag.filterChildren: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: abstractItem.clicked(mouse)
        onPressed: {
            abstractItem.hideToolTip()
            abstractItem.pressed(mouse)
        }
        onPressAndHold: {
            abstractItem.contextMenu(mouse)
        }
        onWheel: {
            abstractItem.wheel(wheel);
            //Don't accept the event in order to make the scrolling by mouse wheel working
            //for the parent scrollview this icon is in.
            wheel.accepted = false;
        }
    }

    PlasmaComponents.Label {
        id: label
        anchors {
            left: parent.left
            leftMargin: iconItem ? iconItem.width + units.smallSpacing : 0
            verticalCenter: parent.verticalCenter
        }
        opacity: labelVisible ? 1 : 0
        visible: abstractItem.hidden
        Behavior on opacity {
            NumberAnimation {
                duration: units.longDuration
                easing.type: Easing.InOutQuad
            }
        }
    }
}

