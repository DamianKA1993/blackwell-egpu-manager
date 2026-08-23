import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
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

    property bool initialLoaded: false
    property int currentMode: 0
    property bool isWaiting: false
    property string igpuName: "Integrated Graphics"
    property string igpuName2: "Integrated GPU"
    property string egpuName: "None"
    property string egpuName2: "None"
    property string pcieLink: "N/A"

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
        interval: 3000
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
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: root.tr("Blackwell eGPU Manager")
            font.bold: true
            font.pixelSize: Kirigami.Units.gridUnit * 0.9
            Layout.fillWidth: true
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

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
                        text: root.currentMode === 4 ? root.tr("Status: Inactive") : (root.currentMode === 3 ? root.tr("Status: Primary Display") : root.tr("Status: Active"))
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
                            return root.tr("Status: Unknown");
                        }
                        font.pixelSize: Kirigami.Units.gridUnit * 0.75
                        opacity: 0.6
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
                        text: root.tr("Connect eGPU")
                        icon.name: root.currentMode === 3 ? "dialog-ok" : "network-connect"
                        enabled: root.currentMode === 2 && !root.isWaiting
                        onClicked: backend.setMode(3)
                    }

                    QQC2.Button {
                        visible: root.currentMode === 3
                        text: root.tr("Screen Manager")
                        icon.name: "preferences-desktop-display"
                        onClicked: backend.openScreenManager()
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Kirigami.Units.smallSpacing
                    visible: root.currentMode >= 2

                    QQC2.Button {
                        text: root.tr("eGPU Only (disconnect iGPU)")
                        icon.name: root.currentMode === 4 ? "dialog-ok" : "video-display"
                        enabled: (root.currentMode === 2 || root.currentMode === 3) && !root.isWaiting
                        onClicked: backend.setMode(4)
                    }

                    QQC2.Button {
                        visible: root.currentMode === 4
                        text: root.tr("Screen Manager")
                        icon.name: "preferences-desktop-display"
                        onClicked: backend.openScreenManager()
                    }
                }

                QQC2.Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: root.currentMode >= 3
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
