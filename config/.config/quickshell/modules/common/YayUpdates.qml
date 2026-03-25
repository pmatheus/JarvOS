import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    property int updateCount: 0
    property bool isChecking: false
    property bool hasUpdates: updateCount > 0
    property string accumulatedOutput: ""
    
    Process {
        id: yayProcess
        command: ["yay", "-Qu"]
        running: false
        
        stdout: SplitParser {
            onRead: data => {
                // Add newline to preserve line separation
                root.accumulatedOutput += data + "\n";
                console.log(`YayUpdates: Received data chunk: "${data}"`);
            }
        }
        
        stderr: SplitParser {
            onRead: errorData => {
                const errorOutput = errorData.trim();
                if (errorOutput) {
                    console.warn(`YayUpdates (Process stderr): ERROR = "${errorOutput}"`);
                }
            }
        }
        
        onExited: (exitCode, exitStatus) => {
            root.isChecking = false;
            console.log(`YayUpdates: Process exited with code ${exitCode}`);
            console.log(`YayUpdates: Full output: "${root.accumulatedOutput}"`);
            
            if (exitCode === 0) {
                const output = root.accumulatedOutput.trim();
                if (output) {
                    const lines = output.split('\n').filter(line => line.trim() !== '');
                    root.updateCount = lines.length;
                    console.log(`YayUpdates: Processed ${lines.length} update lines`);
                } else {
                    root.updateCount = 0;
                    console.log(`YayUpdates: No updates found (empty output)`);
                }
            } else {
                root.updateCount = 0;
                console.log(`YayUpdates: Process failed, setting count to 0`);
            }
            
            // Reset accumulated output for next run
            root.accumulatedOutput = "";
        }
        
        onStarted: {
            root.isChecking = true
        }
    }
    
    function checkUpdates() {
        if (!yayProcess.running) {
            console.log("YayUpdates: Starting update check");
            yayProcess.running = true;
        } else {
            console.log("YayUpdates: Update check already in progress");
        }
    }
    
    Timer {
        id: refreshTimer
        interval: 300000 // 5 minutos
        running: true
        repeat: true
        onTriggered: {
            console.log("YayUpdates: Timer triggered, checking for updates");
            checkUpdates();
        }
    }
    
    Component.onCompleted: {
        checkUpdates()
    }
}