import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

RowLayout {
    id: field

    property string value
    property var options: []
    property string placeholder: i18n("Auto-detect")

    spacing: 4

    QQC2.TextField {
        id: input
        Layout.fillWidth: true
        Layout.minimumWidth: 220
        text: field.value
        placeholderText: field.placeholder
        onTextEdited: field.value = text
    }

    QQC2.Button {
        id: pick
        icon.name: "arrow-down"
        enabled: field.options.length > 0
        onClicked: menu.popup(pick, 0, pick.height)
        QQC2.ToolTip.text: i18n("Choose a detected value")
        QQC2.ToolTip.visible: hovered
    }

    QQC2.Button {
        icon.name: "edit-clear"
        enabled: field.value.length > 0
        onClicked: field.value = ""
        QQC2.ToolTip.text: i18n("Use auto-detection")
        QQC2.ToolTip.visible: hovered
    }

    QQC2.Menu {
        id: menu

        Instantiator {
            model: field.options
            delegate: QQC2.MenuItem {
                required property var modelData
                text: modelData.label
                onTriggered: field.value = modelData.value
            }
            onObjectAdded: (index, object) => menu.insertItem(index, object)
            onObjectRemoved: (index, object) => menu.removeItem(object)
        }
    }
}
