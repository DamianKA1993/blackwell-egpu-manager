import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation

    // Wymiary bazowe widżetu
    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: Kirigami.Units.gridUnit * 24

    // Stan sprzętowy i dane JSON
    property bool initialLoaded: false
    property int currentMode: 0
    property bool isWaiting: false
    property string igpuName: "Integrated Graphics"
    property string egpuName: "None"
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
                    root.egpuName = parsed.egpu;
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

    // Ikona na pasku zadań
    compactRepresentation: MouseArea {
        anchors.fill: parent
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: root.currentMode >= 3 ? "video-display" : "video-television"
        }
    }

    // Główne okno ze stałą geometrią
    fullRepresentation: ColumnLayout {
        implicitWidth: Kirigami.Units.gridUnit * 24
        implicitHeight: Kirigami.Units.gridUnit * 24
        Layout.minimumWidth: Kirigami.Units.gridUnit * 24
        Layout.minimumHeight: Kirigami.Units.gridUnit * 24
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 24
        spacing: Kirigami.Units.largeSpacing

        // Tytuł
        QQC2.Label {
            text: "Blackwell eGPU Manager"
            font.bold: true
            font.pixelSize: Kirigami.Units.gridUnit * 0.9
            Layout.fillWidth: true
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // Ekran ładowania
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
                text: "Checking hardware state..."
                font.pixelSize: Kirigami.Units.gridUnit * 0.8
                opacity: 0.6
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Główna zawartość
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
                    text: "iGPU"
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
                        text: root.igpuName
                        font.bold: true
                        font.pixelSize: Kirigami.Units.gridUnit * 0.8
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        opacity: root.currentMode === 4 ? 0.5 : 1.0
                    }

                    QQC2.Label {
                        text: root.currentMode === 4 ? "Status: Inactive" : (root.currentMode === 3 ? "Status: Primary Display" : "Status: Active")
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
                    text: "eGPU"
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
                        text: root.currentMode === 0 ? "No Blackwell eGPU found" : root.egpuName
                        font.bold: root.currentMode !== 0
                        font.pixelSize: Kirigami.Units.gridUnit * 0.8
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        opacity: root.currentMode === 0 ? 0.5 : 1.0
                    }

                    QQC2.Label {
                        text: "Speed: " + (root.pcieLink !== "" && root.pcieLink !== "N/A" ? root.pcieLink : "N/A")
                        font.pixelSize: Kirigami.Units.gridUnit * 0.75
                        font.bold: root.currentMode >= 3
                        color: root.currentMode >= 3 ? "#27ae60" : Kirigami.Theme.textColor
                        opacity: root.currentMode >= 3 ? 1.0 : 0.6
                        visible: root.currentMode !== 0
                    }

                    QQC2.Label {
                        text: {
                            if (root.currentMode === 0) return "Status: Disconnected";
                            if (root.currentMode === 1) return "Status: Unauthorized (USB4)";
                            if (root.currentMode === 2) return "Status: Standby (Ready)";
                            if (root.currentMode === 3) return "Status: Hybrid Offload";
                            if (root.currentMode === 4) return "Status: Dedicated Primary";
                            return "Status: Unknown";
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
                    text: "Authorize"
                    icon.name: "security-high"
                    enabled: !root.isWaiting
                    onClicked: backend.setMode(2)
                }

                QQC2.Button {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.currentMode >= 2
                    text: "Connect eGPU"
                    icon.name: root.currentMode === 3 ? "dialog-ok" : "network-connect"
                    enabled: root.currentMode === 2 && !root.isWaiting
                    onClicked: backend.setMode(3)
                }

                QQC2.Button {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.currentMode >= 2
                    text: "eGPU Only"
                    icon.name: root.currentMode === 4 ? "dialog-ok" : "video-display"
                    enabled: (root.currentMode === 2 || root.currentMode === 3) && !root.isWaiting
                    onClicked: backend.setMode(4)
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
