import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    radius: Appearance.rounding.small
    color: "transparent"

    property var packagesList: []
    property bool isLoading: false

    // YayUpdates apenas para o contador da aba
    YayUpdates {
        id: yayUpdates
    }

    Process {
        id: packageListProcess
        command: ["yay", "-Qu"]
        running: false
        
        property string accumulatedOutput: ""
        
        stdout: SplitParser {
            onRead: data => {
                packageListProcess.accumulatedOutput += data + "\n";
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            console.log(`UpdatesList: Process exited with code ${exitCode}`)
            console.log(`UpdatesList: Raw output: "${packageListProcess.accumulatedOutput}"`)
            root.isLoading = false
            if (exitCode === 0) {
                const output = packageListProcess.accumulatedOutput.trim();
                console.log(`UpdatesList: Trimmed output: "${output}"`)
                if (output) {
                    const lines = output.split('\n').filter(line => line.trim() !== '');
                    console.log(`UpdatesList: Found ${lines.length} lines:`, lines)
                    root.packagesList = lines.map(line => {
                        const parts = line.trim().split(' ');
                        console.log(`UpdatesList: Parsing line "${line}" -> parts:`, parts)
                        return {
                            name: parts[0],
                            currentVersion: parts[1] || "",
                            newVersion: parts[3] || parts[2] || ""
                        };
                    });
                    console.log(`UpdatesList: Final packagesList:`, root.packagesList)
                } else {
                    console.log("UpdatesList: Empty output, no packages")
                    root.packagesList = [];
                }
            } else {
                console.log(`UpdatesList: Process failed with code ${exitCode}`)
                root.packagesList = [];
            }
            packageListProcess.accumulatedOutput = "";
        }
        
        onStarted: {
            root.isLoading = true
        }
    }

    function loadPackages() {
        console.log(`UpdatesList: loadPackages called, process running: ${packageListProcess.running}`)
        if (!packageListProcess.running) {
            console.log("UpdatesList: Starting process")
            packageListProcess.running = true;
        }
    }

    StyledListView {
        id: listView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: statusRow.top
        anchors.bottomMargin: 5
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 2

        model: root.packagesList
        spacing: 3

        delegate: Rectangle {
            width: listView.width
            height: 60
            color: "transparent"
            radius: Appearance.rounding.small

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                MaterialSymbol {
                    text: "package_2"
                    iconSize: 20
                    color: Appearance.m3colors.m3primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: modelData.name
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: qsTr("%1 → %2").arg(modelData.currentVersion).arg(modelData.newVersion)
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3outline
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    // Placeholder when list is empty
    Item {
        anchors.fill: listView
        visible: root.packagesList.length === 0 && !root.isLoading

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 55
                color: Appearance.m3colors.m3outline
                text: "check_circle"
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3outline
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("System is up to date")
            }
        }
    }

    // Loading placeholder
    Item {
        anchors.fill: listView
        visible: root.isLoading

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 55
                color: Appearance.m3colors.m3outline
                text: "refresh"
                RotationAnimator on rotation {
                    running: root.isLoading
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3outline
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Checking for updates...")
            }
        }
    }

    Item {
        id: statusRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 5

        Layout.fillWidth: true
        implicitHeight: Math.max(
            refreshButton.implicitHeight,
            statusText.implicitHeight
        )

        Rectangle {
            id: statusTextBackground
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            
            implicitWidth: statusText.implicitWidth + 16
            implicitHeight: 30
            radius: 15
            color: Appearance.colors.colLayer2
            
            opacity: root.packagesList.length > 0 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }
            
            StyledText {
                id: statusText
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: `${root.packagesList.length} ${root.packagesList.length === 1 ? 'update' : 'updates'}`
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer2
            }
        }

        RippleButton {
            id: refreshButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: 100
            implicitHeight: 30
            buttonRadius: 15

            colBackground: Appearance.colors.colLayer2
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    text: "refresh"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    RotationAnimator on rotation {
                        running: root.isLoading
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }

                StyledText {
                    text: qsTr("Refresh")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                }
            }

            onClicked: loadPackages()
        }
    }

    Component.onCompleted: {
        console.log("UpdatesList: Component completed")
        // Carrega os pacotes sempre que o componente é criado, independente da aba
        loadPackages()
    }
}