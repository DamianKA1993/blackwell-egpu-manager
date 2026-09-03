import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import "i18n.js" as I18n

PlasmoidItem {
    id: root

    function tr(text, param) {
        return I18n.t(text, param);
    }

    preferredRepresentation: compactRepresentation

    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: Kirigami.Units.gridUnit * 24

    // Domyślnie aplet chowa się przy kliknięciu obok (true)
    hideOnWindowDeactivate: true

    property bool initialLoaded: false
    property int currentMode: 0
    property bool isWaiting: false
    property string igpuName: "Integrated Graphics"
    property string igpuName2: "Integrated GPU"
    property string egpuName: "None"
    property string egpuName2: "None"
    property string pcieLink: "N/A"

    // Właściwości telemetrii eGPU (Mode 3, 4, 5)
    property int gpuUtil: 0
    property real pwrCurr: 0.0
    property real vramUsed: 0.0
    property real vramTotal: 0.0
    property int gpuTemp: 0
    property int pcieRx: 0
    property int pcieTx: 0

    P5Support.DataSource {
        id: backend
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim();

            if (sourceName.indexOf("blackwell-egpu status") !== -1 && stdout.length > 0) {
                try {
                    var parsed = JSON.parse(stdout);
                    root.currentMode = parsed.mode;
                    root.isWaiting = (parsed.wait === 1);
                    root.igpuName = parsed.igpu;
                    root.igpuName2 = parsed.igpu2 || parsed.igpu;
                    root.egpuName = parsed.egpu;
                    root.egpuName2 = parsed.egpu2 || parsed.egpu;
                    root.pcieLink = parsed.link;

                    // Odczyt pól telemetrii
                    root.gpuUtil = parsed.gpu_util || 0;
                    root.pwrCurr = parsed.pwr_curr || 0.0;
                    root.vramUsed = parsed.vram_used || 0.0;
                    root.vramTotal = parsed.vram_total || 0.0;
                    root.gpuTemp = parsed.temp || 0;
                    root.pcieRx = parsed.pcie_rx || 0;
                    root.pcieTx = parsed.pcie_tx || 0;

                    root.initialLoaded = true;
                } catch(e) {
                    console.log("JSON Parse Error:", e);
                }
            }
            disconnectSource(sourceName);
        }

        function refresh() {
            connectSource("blackwell-egpu status");
        }

        function setMode(targetMode) {
            connectSource("sudo blackwell-egpu set " + targetMode);
        }

        function openScreenManager() {
            connectSource("kcmshell6 kcm_kscreen");
        }
    }

    Timer {
        id: pollTimer
        interval: 2000
        running: root.expanded
        repeat: true
        onTriggered: backend.refresh()
    }

    onExpandedChanged: {
        if (expanded) {
            backend.refresh();
        }
    }

    Component.onCompleted: {
        backend.refresh();
    }

    compactRepresentation: MouseArea {
        anchors.fill: parent
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: root.currentMode >= 3 ? "video-display" : "video-television"
        }
    }

    fullRepresentation: ColumnLayout {
        implicitWidth: Kirigami.Units.gridUnit * 24
        implicitHeight: Kirigami.Units.gridUnit * 24
        Layout.minimumWidth: Kirigami.Units.gridUnit * 24
        Layout.minimumHeight: Kirigami.Units.gridUnit * 24
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 24
        spacing: 0

        // === SYSTEMOWY NAGŁÓWEK (BACK ARROW + TITLE + WORKING PIN) ===
        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit * 2.2

            contentItem: RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.ToolButton {
                    icon.name: Qt.application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
                    icon.width: Kirigami.Units.iconSizes.smallMedium
                    icon.height: Kirigami.Units.iconSizes.smallMedium
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        root.expanded = false;
                    }
                }

                Kirigami.Heading {
                    level: 1
                    text: root.tr("Blackwell eGPU Manager")
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                }

                PlasmaComponents.ToolButton {
                    icon.name: "window-pin"
                    icon.width: Kirigami.Units.iconSizes.smallMedium
                    icon.height: Kirigami.Units.iconSizes.smallMedium
                    checkable: true
                    checked: !root.hideOnWindowDeactivate
                    Layout.alignment: Qt.AlignVCenter
                    onToggled: {
                        root.hideOnWindowDeactivate = !checked;
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Item {
            implicitHeight: Kirigami.Units.largeSpacing
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Kirigami.Units.gridUnit * 0.5
            Layout.rightMargin: Kirigami.Units.gridUnit * 0.5
            spacing: Kirigami.Units.largeSpacing

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: Kirigami.Units.largeSpacing
                visible: !root.initialLoaded

                QQC2.BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    running: !root.initialLoaded
                    implicitWidth: Kirigami.Units.gridUnit * 2
                    implicitHeight: Kirigami.Units.gridUnit * 2
                }

                QQC2.Label {
                    text: root.tr("Checking hardware state...")
                    font.pixelSize: Kirigami.Units.gridUnit * 0.8
                    opacity: 0.6
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.largeSpacing
                visible: root.initialLoaded

                // === SEKCJA iGPU ===
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: root.tr("iGPU")
                        font.bold: true
                        font.pixelSize: Kirigami.Units.gridUnit * 0.75
                        opacity: 0.7
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        source: "video-television"
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: Kirigami.Units.iconSizes.medium
                        opacity: root.currentMode === 4 ? 0.4 : 1.0
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        QQC2.Label {
                            text: root.igpuName2
                            font.bold: true
                            font.pixelSize: Kirigami.Units.gridUnit * 0.8
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            opacity: root.currentMode === 4 ? 0.5 : 1.0
                        }

                        QQC2.Label {
                            text: root.tr("Device: %1", root.igpuName)
                            font.pixelSize: Kirigami.Units.gridUnit * 0.7
                            opacity: 0.5
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            visible: root.igpuName !== "" && root.igpuName !== root.igpuName2
                        }

                        QQC2.Label {
                            text: {
                                if (root.currentMode === 4) return root.tr("Status: Inactive");
                                if (root.currentMode === 3) return root.tr("Status: Primary Display");
                                if (root.currentMode === 5) return root.tr("Status: Active (Restored)");
                                return root.tr("Status: Active");
                            }
                            font.pixelSize: Kirigami.Units.gridUnit * 0.75
                            opacity: 0.6
                        }
                    }
                }

                // === SEKCJA eGPU ===
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: root.tr("eGPU")
                        font.bold: true
                        font.pixelSize: Kirigami.Units.gridUnit * 0.75
                        opacity: 0.7
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        source: "video-display"
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: Kirigami.Units.iconSizes.medium
                        opacity: root.currentMode === 0 ? 0.4 : 1.0
                    }

                    // Lewa strona: Dane sprzętowe
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        QQC2.Label {
                            text: {
                                if (root.currentMode === 0) return root.tr("No Blackwell eGPU found");
                                if (root.egpuName2 !== "None" && root.egpuName2 !== "NVIDIA Graphics" && root.egpuName2 !== "") return root.egpuName2;
                                return root.egpuName;
                            }
                            font.bold: root.currentMode !== 0
                            font.pixelSize: Kirigami.Units.gridUnit * 0.8
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            opacity: root.currentMode === 0 ? 0.5 : 1.0
                        }

                        QQC2.Label {
                            text: root.tr("Box: %1", root.egpuName)
                            font.pixelSize: Kirigami.Units.gridUnit * 0.7
                            opacity: 0.5
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            visible: root.currentMode !== 0 && root.egpuName2 !== "None" && root.egpuName2 !== "" && root.egpuName2 !== root.egpuName
                        }

                        QQC2.Label {
                            text: root.tr("Authorized: %1", root.currentMode >= 2 ? root.tr("yes") : root.tr("no"))
                            font.pixelSize: Kirigami.Units.gridUnit * 0.7
                            opacity: 0.6
                            visible: root.currentMode !== 0
                        }

                        QQC2.Label {
                            text: root.tr("Speed: %1", (root.pcieLink !== "" && root.pcieLink !== "N/A" ? root.pcieLink : "N/A"))
                            font.pixelSize: Kirigami.Units.gridUnit * 0.75
                            font.bold: root.currentMode >= 3
                            color: root.currentMode >= 3 ? "#27ae60" : Kirigami.Theme.textColor
                            opacity: root.currentMode >= 3 ? 1.0 : 0.6
                            visible: root.currentMode !== 0
                        }

                        QQC2.Label {
                            text: {
                                if (root.currentMode === 0) return root.tr("Status: Disconnected");
                                if (root.currentMode === 1) return root.tr("Status: Unauthorized (USB4)");
                                if (root.currentMode === 2) return root.tr("Status: Standby (Ready)");
                                if (root.currentMode === 3) return root.tr("Status: Hybrid Offload");
                                if (root.currentMode === 4) return root.tr("Status: Dedicated Primary");
                                if (root.currentMode === 5) return root.tr("Status: Hybrid Offload");
                                return root.tr("Status: Unknown");
                            }
                            font.pixelSize: Kirigami.Units.gridUnit * 0.75
                            opacity: 0.6
                        }
                    }

                    // Prawa strona: Telemetria o stałej szerokości 105px
                    ColumnLayout {
                        visible: root.currentMode >= 3
                        Layout.minimumWidth: 115
                        Layout.rightMargin: Kirigami.Units.gridUnit * 0.25
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                        spacing: 2

                        Item {
                            implicitHeight: Kirigami.Units.gridUnit * 0.1
                        }

                        // Sekcja Usage
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: usageLabel.implicitHeight

                            QQC2.Label {
                                id: usageLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.tr("Usage")
                                font.pixelSize: Kirigami.Units.gridUnit * 0.7
                                opacity: 0.8
                            }

                            QQC2.Label {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.gpuUtil + "% (" + Math.round(root.pwrCurr) + " W)"
                                font.pixelSize: Kirigami.Units.gridUnit * 0.7
                                opacity: 0.8
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.bottomMargin: Kirigami.Units.smallSpacing * 2
                            implicitHeight: 4
                            radius: 2
                            color: Kirigami.Theme.disabledTextColor
                            opacity: 0.3

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.min(parent.width, Math.max(0, parent.width * (root.gpuUtil / 100.0)))
                                radius: 2
                                color: root.gpuUtil >= 90 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
                            }
                        }

                        // Sekcja VRAM
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: vramLabel.implicitHeight

                            QQC2.Label {
                                id: vramLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.tr("VRAM")
                                font.pixelSize: Kirigami.Units.gridUnit * 0.7
                                opacity: 0.8
                            }

                            QQC2.Label {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: (root.vramUsed / 1024).toFixed(1) + " / " + (root.vramTotal / 1024).toFixed(0) + " GB"
                                font.pixelSize: Kirigami.Units.gridUnit * 0.7
                                opacity: 0.8
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 4
                            radius: 2
                            color: Kirigami.Theme.disabledTextColor
                            opacity: 0.3

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.min(parent.width, Math.max(0, root.vramTotal > 0 ? parent.width * (root.vramUsed / root.vramTotal) : 0))
                                radius: 2
                                color: (root.vramTotal > 0 && (root.vramUsed / root.vramTotal) >= 0.9) ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
                            }
                        }

                        // Sekcja PCIe RX / TX (Przylegająca bezpośrednio pod paskiem)
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: rxLabel.implicitHeight
                            Layout.bottomMargin: Kirigami.Units.smallSpacing * 2

                            QQC2.Label {
                                id: rxLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "↓ " + root.pcieTx + " MB/s"
                                font.pixelSize: Kirigami.Units.gridUnit * 0.68
                                opacity: root.pcieTx > 0 ? 1.0 : 0.6
                                color: root.pcieTx > 100 ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                            }

                            QQC2.Label {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "↑ " + root.pcieRx + " MB/s"
                                font.pixelSize: Kirigami.Units.gridUnit * 0.68
                                opacity: root.pcieRx > 0 ? 1.0 : 0.6
                                color: root.pcieRx > 100 ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                            }
                        }

                        // Sekcja Temp
                        RowLayout {
                            Layout.fillWidth: true

                            QQC2.Label {
                                text: root.tr("Temp")
                                font.pixelSize: Kirigami.Units.gridUnit * 0.7
                                opacity: 0.8
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            QQC2.Label {
                                text: root.gpuTemp + "°C"
                                font.pixelSize: Kirigami.Units.gridUnit * 0.7
                                color: root.gpuTemp >= 80 ? Kirigami.Theme.negativeTextColor : (root.gpuTemp >= 70 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor)
                                opacity: root.gpuTemp >= 70 ? 1.0 : 0.8
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                // Przyciski akcji
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Button {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.currentMode === 1
                        text: root.tr("Authorize")
                        icon.name: "security-high"
                        enabled: !root.isWaiting
                        onClicked: backend.setMode(2)
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Kirigami.Units.smallSpacing
                        visible: root.currentMode >= 2

                        QQC2.Button {
                            text: {
                                if (root.currentMode === 4) return root.tr("Connect iGPU");
                                return root.tr("Connect eGPU");
                            }
                            icon.name: {
                                if (root.currentMode === 4) return "video-television";
                                if (root.currentMode >= 3) return "dialog-ok";
                                return "network-connect";
                            }
                            enabled: (root.currentMode === 2 || root.currentMode === 4) && !root.isWaiting
                            onClicked: {
                                if (root.currentMode === 4) {
                                    backend.setMode(5);
                                } else {
                                    backend.setMode(3);
                                }
                            }
                        }

                        QQC2.Button {
                            visible: root.currentMode >= 3
                            text: root.tr("Screen Manager")
                            icon.name: "preferences-desktop-display"
                            onClicked: backend.openScreenManager()
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Kirigami.Units.smallSpacing
                        visible: root.currentMode >= 3

                        QQC2.Button {
                            visible: root.currentMode === 3 || root.currentMode === 5
                            text: root.currentMode === 5 ? root.tr("iGPU Active") : root.tr("eGPU Only (disconnect iGPU)")
                            icon.name: root.currentMode === 5 ? "dialog-ok" : "video-display"
                            enabled: root.currentMode === 3 && !root.isWaiting
                            onClicked: backend.setMode(4)
                        }

                        QQC2.Button {
                            visible: root.currentMode === 3 || root.currentMode === 5
                            text: root.tr("Safely Remove eGPU")
                            icon.name: "media-eject"
                            enabled: root.currentMode === 3 && !root.isWaiting
                            onClicked: backend.setMode(6)
                        }
                    }

                    QQC2.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        visible: root.currentMode === 3
                        text: root.tr("Warning: Disabling the iGPU is experimental. Proceed at your own risk.")
                        font.italic: true
                        font.pixelSize: Kirigami.Units.gridUnit * 0.65
                        opacity: 0.5
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
