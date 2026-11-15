import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Displays & Audio")
        icon: "video-display"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Apps")
        icon: "applications-multimedia"
        source: "configApps.qml"
    }
}
