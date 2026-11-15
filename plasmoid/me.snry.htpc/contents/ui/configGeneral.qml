import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    id: page

    property alias cfg_tvOutput: tvOutput.value
    property alias cfg_tvMode: tvMode.value
    property alias cfg_tvScale: tvScale.value
    property alias cfg_monitor1Output: monitor1Output.value
    property alias cfg_monitor1Mode: monitor1Mode.value
    property alias cfg_monitor2Output: monitor2Output.value
    property alias cfg_monitor2Mode: monitor2Mode.value
    property alias cfg_monitor2Position: monitor2Position.value
    property alias cfg_desktopSink: desktopSink.value
    property alias cfg_couchSink: couchSink.value

    property var info: ({ outputs: [], sinks: [] })
    property bool loading: true
    property string loadError: ""

    function outputOptions() {
        return info.outputs.filter(o => o.connected).map(o => ({
            value: o.name,
            label: o.name + (o.enabled ? i18n(" (on)") : i18n(" (off)"))
        }));
    }

    function modeOptions(name, fallbackHdmi) {
        let out = info.outputs.find(o => o.name === name);
        if (!out && fallbackHdmi) {
            out = info.outputs.find(o => o.connected && o.name.startsWith("HDMI"));
        }
        return out ? out.modes.map(m => ({ value: m, label: m })) : [];
    }

    function sinkOptions() {
        return info.sinks.map(s => ({ value: s.name, label: s.description + "  —  " + s.name }));
    }

    function reload() {
        loading = true;
        loadError = "";
        executable.connectSource("PATH=\"$HOME/.local/bin:$PATH\" snry-htpc list #" + Date.now());
    }

    Component.onCompleted: reload()

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            page.loading = false;
            try {
                page.info = JSON.parse(data["stdout"]);
            } catch (e) {
                page.loadError = i18n("Could not run snry-htpc: %1", (data["stderr"] || String(e)).trim());
            }
        }
    }

    Kirigami.FormLayout {
        Kirigami.InlineMessage {
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Leave a field empty to auto-detect. These settings are shared with the snry-htpc command (KDE Connect, shortcuts).")
            visible: true
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
            text: page.loadError
            visible: page.loadError.length > 0
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("TV (couch mode)")
        }
        PickerField {
            id: tvOutput
            Kirigami.FormData.label: i18n("Output:")
            placeholder: i18n("Auto-detect (first HDMI)")
            options: page.outputOptions()
        }
        PickerField {
            id: tvMode
            Kirigami.FormData.label: i18n("Mode:")
            placeholder: i18n("Keep current")
            options: page.modeOptions(tvOutput.value, true)
        }
        PickerField {
            id: tvScale
            Kirigami.FormData.label: i18n("Scale:")
            placeholder: i18n("Keep current")
            options: [1, 1.25, 1.5, 1.75, 2].map(s => ({ value: String(s), label: Math.round(s * 100) + "%" }))
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Monitors (desktop mode)")
        }
        PickerField {
            id: monitor1Output
            Kirigami.FormData.label: i18n("Monitor 1:")
            placeholder: i18n("Auto-detect (leftmost non-TV)")
            options: page.outputOptions()
        }
        PickerField {
            id: monitor1Mode
            Kirigami.FormData.label: i18n("Monitor 1 mode:")
            placeholder: i18n("Keep current")
            options: page.modeOptions(monitor1Output.value, false)
        }
        PickerField {
            id: monitor2Output
            Kirigami.FormData.label: i18n("Monitor 2:")
            placeholder: i18n("Auto-detect (next non-TV)")
            options: page.outputOptions()
        }
        PickerField {
            id: monitor2Mode
            Kirigami.FormData.label: i18n("Monitor 2 mode:")
            placeholder: i18n("Keep current")
            options: page.modeOptions(monitor2Output.value, false)
        }
        PickerField {
            id: monitor2Position
            Kirigami.FormData.label: i18n("Monitor 2 position:")
            placeholder: i18n("Right of monitor 1 (x,y)")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Audio")
        }
        PickerField {
            id: desktopSink
            Kirigami.FormData.label: i18n("Desktop output:")
            placeholder: i18n("Restore the one used before couch mode")
            options: page.sinkOptions()
        }
        PickerField {
            id: couchSink
            Kirigami.FormData.label: i18n("TV output:")
            placeholder: i18n("Auto-detect (first HDMI sink)")
            options: page.sinkOptions()
        }

        QQC2.Button {
            Kirigami.FormData.label: page.loading ? i18n("Detecting…") : ""
            icon.name: "view-refresh"
            text: i18n("Re-detect outputs and audio devices")
            enabled: !page.loading
            onClicked: page.reload()
        }
    }
}
