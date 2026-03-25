// root:/modules/common/ipfetcher.qml
import QtQuick
import Quickshell.Io
import Quickshell

Item {
    id: root

    property string ipAddress: ""
    property bool tun0IsUp: false

    // Uma propriedade temporária para saber se o IP foi encontrado NESTE ciclo de Process.
    property bool ipFoundThisCycle: false

    Process {
        id: ipProcess
        command: ["bash", "-c", "ip -4 addr show tun0 | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}'"]
        running: true // Inicia automaticamente na criação

        stdout: SplitParser {
            onRead: data => {
                const output = data.trim();
                console.log(`ipfetcher.qml (Process stdout): DATA = "${output}"`);
                if (output) {
                    root.ipAddress = output;
                    root.tun0IsUp = true;
                    root.ipFoundThisCycle = true; // <<<<<< MARCAR QUE UM IP FOI ENCONTRADO
                    console.log(`ipfetcher.qml: IP updated to: ${root.ipAddress}`);
                }
                // Nao resetamos aqui! O onExited fará isso se nao houver IP.
            }
        }
        
        stderr: SplitParser {
            onRead: errorData => {
                const errorOutput = errorData.trim();
                if (errorOutput) {
                    console.warn(`ipfetcher.qml (Process stderr): ERROR = "${errorOutput}"`);
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.log(`ipfetcher.qml (Process): Command exited with code ${exitCode}, status ${exitStatus}.`);
            
            // SOMENTE reseta se o IP NÃO foi encontrado neste ciclo
            if (!root.ipFoundThisCycle) {
                root.ipAddress = "";
                root.tun0IsUp = false;
                console.log("ipfetcher.qml: No IP found in this cycle. Resetting IP/tun0 status.");
            }
            
            // Resetar a flag para o proximo ciclo
            root.ipFoundThisCycle = false; 
        }

        Component.onCompleted: {
            console.log(`ipfetcher.qml (Process): Process component created. Initial command: ${command}`);
        }
    }

    Timer {
        id: refreshTrigger
        interval: 5000 // A cada 5 segundos
        running: true
        repeat: true
        onTriggered: {
            console.log("ipfetcher.qml: Timer triggered. Restarting IP process.");
            
            // NADA DE RESET AQUI! O IP só vai sumir se o comando nao encontrar nada.
            // root.ipAddress = ""; // REMOVER ESTA LINHA!
            // root.tun0IsUp = false; // REMOVER ESTA LINHA!
            // console.log("ipfetcher.qml: IP/tun0 status reset before restart."); // REMOVER ESTA LINHA!

            ipProcess.running = false;
            ipProcess.running = true;
        }
    }

    Component.onCompleted: {
        console.log("ipfetcher.qml: Componente IpFetcher inicializado.");
        // Não resetamos aqui também para evitar piscar na inicialização se o IP ja estiver la.
        // O primeiro run do Process vai preencher.
        // root.ipAddress = ""; // REMOVER ESTA LINHA!
        // root.tun0IsUp = false; // REMOVER ESTA LINHA!
    }
}