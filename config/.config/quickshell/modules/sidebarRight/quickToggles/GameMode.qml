import "root:/modules/common"
import "root:/modules/common/widgets"
import "../"
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "root:/services/Config" // Importamos o serviço de Config

QuickToggleButton {
    id: root
    buttonIcon: "gamepad"
    toggled: toggled

    // Armazenamos o valor original do cornerStyle
    property var originalCornerStyle: Config.options.bar.cornerStyle

    onClicked: {
        root.toggled = !root.toggled
        if (root.toggled) {
            // Ativar Game Mode
            Quickshell.execDetached(["bash", "-c", `hyprctl --batch "keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword decoration:inactive_opacity 1; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0; keyword general:allow_tearing 1"`])

            // Salva o valor original antes de mudar para 2
            originalCornerStyle = Config.options.bar.cornerStyle;
            Config.options.bar.cornerStyle = 2; // Define o novo valor
        } else {
            // Desativar Game Mode
            Quickshell.execDetached(["hyprctl", "reload"])

            // Volta cornerStyle para o valor original
            Config.options.bar.cornerStyle = originalCornerStyle;
        }
    }

    Process {
        id: fetchActiveState
        running: true
        command: ["bash", "-c", `test "$(hyprctl getoption animations:enabled -j | jq ".int")" -ne 0`]
        onExited: (exitCode, exitStatus) => {
            root.toggled = exitCode !== 0 // Inverted because enabled = nonzero exit
        }
    }
    StyledToolTip {
        content: qsTr("Game mode")
    }
}