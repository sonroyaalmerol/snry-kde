import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property var syncKeys: ["tvOutput", "tvMode", "tvScale", "monitor1Output", "monitor1Mode", "monitor2Output", "monitor2Mode", "monitor2Position", "desktopSink", "couchSink", "kodiCommand", "steamGamescope", "notifications"]
    readonly property var boolKeys: ["steamGamescope", "notifications"]
    readonly property string cli: "PATH=\"$HOME/.local/bin:$PATH\" snry-htpc"

    property string mode: "unknown"
    property bool busy: false
    property string busyText: ""
    property string lastError: ""
    property bool configReady: false
    property int seq: 0
    property var pending: ({})

    readonly property string modeText: {
        switch (mode) {
        case "couch": return i18n("Couch mode — TV");
        case "desktop": return i18n("Desktop mode — monitors");
        case "mixed": return i18n("Mixed — TV and monitors on");
        default: return i18n("Unknown display state");
        }
    }

    readonly property string configSignature: JSON.stringify(syncKeys.map(k => Plasmoid.configuration[k]))

    Plasmoid.icon: mode === "couch" ? "video-television" : "video-display"
    toolTipMainText: i18n("HTPC Mode")
    toolTipSubText: busy ? busyText : modeText + "\n" + i18n("Middle-click to toggle")

    function shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function rcKey(k) {
        return k.charAt(0).toUpperCase() + k.slice(1);
    }

    function run(args, cb) {
        seq += 1;
        const cmd = cli + " " + args.map(shq).join(" ") + " #" + seq;
        pending[cmd] = cb || null;
        executable.connectSource(cmd);
    }

    function refresh() {
        run(["mode", "status"], (code, out) => {
            const m = out.trim();
            root.mode = m.length > 0 ? m : "unknown";
        });
    }

    function lastLine(text) {
        const lines = String(text).trim().split("\n").filter(l => l.length > 0);
        return lines.length ? lines[lines.length - 1].replace(/^snry-htpc: /, "") : "";
    }

    function switchMode(target) {
        if (busy) {
            return;
        }
        busy = true;
        busyText = target === "couch" ? i18n("Switching to the TV…") : target === "desktop" ? i18n("Switching to the monitors…") : i18n("Switching…");
        lastError = "";
        run(["mode", target], (code, out, err) => {
            root.busy = false;
            if (code !== 0) {
                root.lastError = root.lastLine(err) || i18n("Switching failed (exit code %1)", code);
            }
            root.refresh();
        });
    }

    function launch(app) {
        lastError = "";
        run(["launch", app], (code, out, err) => {
            if (code !== 0) {
                root.lastError = root.lastLine(err) || i18n("Could not launch %1", app);
            }
            followUp.restart();
        });
    }

    function stopApps() {
        run(["stop"], () => followUp.restart());
    }

    function syncConfig() {
        const rc = {};
        for (const k of syncKeys) {
            const v = Plasmoid.configuration[k];
            rc[rcKey(k)] = boolKeys.indexOf(k) >= 0 ? (v ? "true" : "false") : String(v === undefined ? "" : v);
        }
        run(["config", "set-json", JSON.stringify(rc)]);
    }

    function importConfig() {
        run(["config", "json"], (code, out) => {
            try {
                const rc = JSON.parse(out);
                for (const k of root.syncKeys) {
                    const v = rc[root.rcKey(k)];
                    if (v === undefined || v === "") {
                        continue;
                    }
                    Plasmoid.configuration[k] = root.boolKeys.indexOf(k) >= 0 ? (v === "true") : v;
                }
            } catch (e) {
                console.warn("snry-htpc: could not import config:", e);
            }
            Plasmoid.configuration.imported = true;
            root.configReady = true;
            syncTimer.restart();
        });
    }

    onConfigSignatureChanged: {
        if (configReady) {
            syncTimer.restart();
        }
    }

    onExpandedChanged: isExpanded => {
        if (isExpanded) {
            refresh();
        }
    }

    Component.onCompleted: {
        refresh();
        if (Plasmoid.configuration.imported) {
            configReady = true;
            syncTimer.restart();
        } else {
            importConfig();
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            const cb = root.pending[sourceName];
            delete root.pending[sourceName];
            disconnectSource(sourceName);
            if (cb) {
                cb(data["exit code"], data["stdout"] || "", data["stderr"] || "");
            }
        }
    }

    Timer {
        id: syncTimer
        interval: 400
        onTriggered: root.syncConfig()
    }

    Timer {
        id: followUp
        interval: 2500
        repeat: true
        property int left: 4
        onTriggered: {
            root.refresh();
            left -= 1;
            if (left <= 0) {
                stop();
                left = 4;
            }
        }
    }

    Timer {
        interval: root.expanded ? 3000 : 20000
        repeat: true
        running: !root.busy
        onTriggered: root.refresh()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Desktop Mode")
            icon.name: "video-display"
            enabled: !root.busy && root.mode !== "desktop"
            onTriggered: root.switchMode("desktop")
        },
        PlasmaCore.Action {
            text: i18n("Couch Mode")
            icon.name: "video-television"
            enabled: !root.busy && root.mode !== "couch"
            onTriggered: root.switchMode("couch")
        },
        PlasmaCore.Action {
            isSeparator: true
        },
        PlasmaCore.Action {
            text: i18n("Kodi on TV")
            icon.name: "kodi"
            onTriggered: root.launch("kodi")
        },
        PlasmaCore.Action {
            text: i18n("Steam Big Picture on TV")
            icon.name: "steam"
            onTriggered: root.launch("steam")
        }
    ]

    compactRepresentation: MouseArea {
        id: compact
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        property bool wasExpanded: false
        onPressed: mouse => {
            wasExpanded = root.expanded;
        }
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.switchMode("toggle");
            } else {
                root.expanded = !wasExpanded;
            }
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compact.containsMouse
            opacity: root.busy ? 0.4 : 1
        }

        PlasmaComponents3.BusyIndicator {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            visible: root.busy
            running: visible
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Icon {
                    source: Plasmoid.icon
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Kirigami.Heading {
                        level: 3
                        text: i18n("HTPC Mode")
                    }
                    PlasmaComponents3.Label {
                        text: root.busy ? root.busyText : root.modeText
                        opacity: 0.7
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "configure"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Configure…")
                    onClicked: Plasmoid.internalAction("configure").trigger()
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                }
            }
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    icon.name: "video-display"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    text: root.mode === "desktop" ? i18n("Desktop ✓") : i18n("Desktop")
                    enabled: !root.busy && root.mode !== "desktop"
                    onClicked: root.switchMode("desktop")
                }
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    icon.name: "video-television"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    text: root.mode === "couch" ? i18n("Couch ✓") : i18n("Couch")
                    enabled: !root.busy && root.mode !== "couch"
                    onClicked: root.switchMode("couch")
                }
            }

            Kirigami.Heading {
                level: 5
                text: i18n("Launch on the TV")
                visible: Plasmoid.configuration.showLaunchers
                opacity: 0.8
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.showLaunchers
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    icon.name: "kodi"
                    text: i18n("Kodi")
                    enabled: !root.busy
                    onClicked: root.launch("kodi")
                }
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    icon.name: "steam"
                    text: i18n("Steam")
                    enabled: !root.busy
                    onClicked: root.launch("steam")
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "media-playback-stop"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Stop TV apps")
                    onClicked: root.stopApps()
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
                text: root.lastError
                visible: root.lastError.length > 0
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
