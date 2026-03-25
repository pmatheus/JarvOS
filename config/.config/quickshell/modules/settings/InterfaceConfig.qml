import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "root:/services/"
import "root:/modules/common/"
import "root:/modules/common/widgets/"

ContentPage {
    forceWidth: true

    ContentSection {
        title: "Bar"

        ContentSubsection {
            title: "Multi-monitor"
            ConfigSwitch {
                text: 'Simplified bars on secondary monitors'
                checked: Config.options.bar.multiMonitorMode ?? false
                onCheckedChanged: {
                    Config.options.bar.multiMonitorMode = checked;
                }
                StyledToolTip {
                    content: "Show only workspaces on secondary monitors"
                }
            }
            
            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: "Primary monitor name (e.g., DP-1, HDMI-A-1)"
                text: Config.options.bar.primaryMonitor
                onTextChanged: {
                    Config.options.bar.primaryMonitor = text;
                }
                enabled: Config.options.bar.multiMonitorMode
                visible: Config.options.bar.multiMonitorMode
            }
        }

        ContentSubsection {
            title: "Buttons"
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: "Screen snip"
                    checked: Config.options.bar.utilButtons.showScreenSnip
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showScreenSnip = checked;
                    }
                }
                ConfigSwitch {
                    text: "Color picker"
                    checked: Config.options.bar.utilButtons.showColorPicker
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showColorPicker = checked;
                    }
                }
            }
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: "Mic toggle"
                    checked: Config.options.bar.utilButtons.showMicToggle
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showMicToggle = checked;
                    }
                }
                ConfigSwitch {
                    text: "Keyboard toggle"
                    checked: Config.options.bar.utilButtons.showKeyboardToggle
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showKeyboardToggle = checked;
                    }
                }
            }
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: "Dark/Light toggle"
                    checked: Config.options.bar.utilButtons.showDarkModeToggle
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showDarkModeToggle = checked;
                    }
                }
                ConfigSwitch {
                    opacity: 0
                    enabled: false
                }
            }
        }

        ContentSubsection {
            title: "Workspaces"
            tooltip: "Tip: Hide icons and always show numbers for\nthe classic illogical-impulse experience"

            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: 'Show app icons'
                    checked: Config.options.bar.workspaces.showAppIcons
                    onCheckedChanged: {
                        Config.options.bar.workspaces.showAppIcons = checked;
                    }
                }
                ConfigSwitch {
                    text: 'Always show numbers'
                    checked: Config.options.bar.workspaces.alwaysShowNumbers
                    onCheckedChanged: {
                        Config.options.bar.workspaces.alwaysShowNumbers = checked;
                    }
                }
            }
            ConfigSpinBox {
                text: "Workspaces shown"
                value: Config.options.bar.workspaces.shown
                from: 1
                to: 30
                stepSize: 1
                onValueChanged: {
                    Config.options.bar.workspaces.shown = value;
                }
            }
            ConfigSpinBox {
                text: "Number show delay when pressing Super (ms)"
                value: Config.options.bar.workspaces.showNumberDelay
                from: 0
                to: 1000
                stepSize: 50
                onValueChanged: {
                    Config.options.bar.workspaces.showNumberDelay = value;
                }
            }
        }   
    }


    ContentSection {
        title: "Overview"
        ConfigSpinBox {
            text: "Scale (%)"
            value: Config.options.overview.scale * 100
            from: 1
            to: 100
            stepSize: 1
            onValueChanged: {
                Config.options.overview.scale = value / 100;
            }
        }
        ConfigRow {
            uniform: true
            ConfigSpinBox {
                text: "Rows"
                value: Config.options.overview.rows
                from: 1
                to: 20
                stepSize: 1
                onValueChanged: {
                    Config.options.overview.rows = value;
                }
            }
            ConfigSpinBox {
                text: "Columns"
                value: Config.options.overview.columns
                from: 1
                to: 20
                stepSize: 1
                onValueChanged: {
                    Config.options.overview.columns = value;
                }
            }
        }
        
    }
}