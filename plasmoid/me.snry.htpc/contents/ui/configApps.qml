import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_kodiCommand: kodiCommand.text
    property alias cfg_steamGamescope: steamGamescope.checked
    property alias cfg_notifications: notifications.checked
    property alias cfg_showLaunchers: showLaunchers.checked

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showLaunchers
            Kirigami.FormData.label: i18n("Widget:")
            text: i18n("Show Kodi / Steam launchers")
        }
        QQC2.CheckBox {
            id: notifications
            text: i18n("Show notifications when switching")
        }
        QQC2.TextField {
            id: kodiCommand
            Kirigami.FormData.label: i18n("Kodi command:")
            placeholderText: "kodi"
        }
        QQC2.CheckBox {
            id: steamGamescope
            Kirigami.FormData.label: i18n("Steam:")
            text: i18n("Run Big Picture inside gamescope")
        }
    }
}
