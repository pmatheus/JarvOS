import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "root:/services/"
import "root:/modules/common/"
import "root:/modules/common/widgets/"

ContentPage {
    forceWidth: true

    ContentSection {
        title: "Time"

        ContentSubsection {
            title: "Format"
            tooltip: ""

            ConfigSelectionArray {
                currentValue: Config.options.time.format
                configOptionName: "time.format"
                onSelected: newValue => {
                    Config.options.time.format = newValue;
                }
                options: [
                    {
                        displayName: "24h",
                        value: "hh:mm"
                    },
                    {
                        displayName: "12h am/pm",
                        value: "h:mm ap"
                    },
                    {
                        displayName: "12h AM/PM",
                        value: "h:mm AP"
                    },
                ]
            }
        }
    }

    ContentSection {
        title: "Weather"

        ConfigRow {
            uniform: false
            ConfigSwitch {
                text: "Enable"
                checked: Config.options.bar.weather.enable
                onCheckedChanged: {
                    Config.options.bar.weather.enable = checked;
                }
                StyledToolTip {
                    content: "Enables weather data fetching for the clock widget"
                }
            }
            ConfigSwitch {
                text: "Imperial units"
                checked: Config.options.bar.weather.useUSCS
                onCheckedChanged: {
                    Config.options.bar.weather.useUSCS = checked;
                }
                enabled: Config.options.bar.weather.enable
                StyledToolTip {
                    content: "Use Fahrenheit and mph instead of Celsius and km/h"
                }
            }
        }

        MaterialTextField {
            Layout.fillWidth: true
            placeholderText: "Enter city name (e.g. São Paulo, London, Tokyo)"
            text: Config.options.bar.weather.city
            onTextChanged: {
                Config.options.bar.weather.city = text;
            }
            enabled: Config.options.bar.weather.enable
        }

        ConfigSpinBox {
            text: "Update interval (minutes)"
            value: Config.options.bar.weather.fetchInterval
            from: 1
            to: 120
            stepSize: 1
            onValueChanged: {
                Config.options.bar.weather.fetchInterval = value;
            }
            enabled: Config.options.bar.weather.enable
        }
    }

    ContentSection {
        title: "Night Light"

        ConfigSwitch {
            text: "Automatic night light"
            checked: Config.options.light.night.automatic
            onCheckedChanged: {
                Config.options.light.night.automatic = checked;
            }
            StyledToolTip {
                content: "Automatically enables night light based on time schedule"
            }
        }

        ConfigRow {
            uniform: true
            MaterialTextField {
                Layout.preferredWidth: 120
                placeholderText: "From"
                text: Config.options.light.night.from
                onTextChanged: {
                    if (/^\d{2}:\d{2}$/.test(text)) {
                        Config.options.light.night.from = text;
                    }
                }
                enabled: Config.options.light.night.automatic
                StyledToolTip {
                    content: "Start time for night light (24h format: HH:MM)"
                }
            }
            MaterialTextField {
                Layout.preferredWidth: 120
                placeholderText: "Until"
                text: Config.options.light.night.to
                onTextChanged: {
                    if (/^\d{2}:\d{2}$/.test(text)) {
                        Config.options.light.night.to = text;
                    }
                }
                enabled: Config.options.light.night.automatic
                StyledToolTip {
                    content: "End time for night light (24h format: HH:MM)"
                }
            }
        }

        ConfigSpinBox {
            text: "Color temperature (K)"
            value: Config.options.light.night.colorTemperature
            from: 1000
            to: 6500
            stepSize: 100
            onValueChanged: {
                Config.options.light.night.colorTemperature = value;
            }
            enabled: Config.options.light.night.automatic
        
        }
    }
    
    ContentSection {
        title: "Audio"

        ConfigSwitch {
            text: "Earbang protection"
            checked: Config.options.audio.protection.enable
            onCheckedChanged: {
                Config.options.audio.protection.enable = checked;
            }
            StyledToolTip {
                content: "Prevents abrupt increments and restricts volume limit"
            }
        }
        ConfigRow {
            // uniform: true
            ConfigSpinBox {
                text: "Max allowed increase"
                value: Config.options.audio.protection.maxAllowedIncrease
                from: 0
                to: 100
                stepSize: 2
                onValueChanged: {
                    Config.options.audio.protection.maxAllowedIncrease = value;
                }
            }
            ConfigSpinBox {
                text: "Volume limit"
                value: Config.options.audio.protection.maxAllowed
                from: 0
                to: 100
                stepSize: 2
                onValueChanged: {
                    Config.options.audio.protection.maxAllowed = value;
                }
            }
        }
    }

    ContentSection {
        title: "Battery"

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                text: "Low warning"
                value: Config.options.battery.low
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.low = value;
                }
            }
            ConfigSpinBox {
                text: "Critical warning"
                value: Config.options.battery.critical
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.critical = value;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                text: "Automatic suspend"
                checked: Config.options.battery.automaticSuspend
                onCheckedChanged: {
                    Config.options.battery.automaticSuspend = checked;
                }
                StyledToolTip {
                    content: "Automatically suspends the system when battery is low"
                }
            }
            ConfigSpinBox {
                text: "Suspend at"
                value: Config.options.battery.suspend
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.suspend = value;
                }
            }
        }
    }


    ContentSection {
        title: "Resources"
        ConfigSpinBox {
            text: "Polling interval (seconds)"
            value: Config.options.resources.updateInterval
            from: 1
            to: 100
            stepSize: 1
            onValueChanged: {
                Config.options.resources.updateInterval = value;
            }
        }
    }

    
}