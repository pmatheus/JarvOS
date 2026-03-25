import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0
        
        // 1. Data com ícone
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 25
            spacing: 8
            
            MaterialSymbol {
                text: "calendar_today"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
                opacity: 1
            }
            
            StyledText {
                id: dateText
                text: Qt.locale().toString(new Date(), "dddd, MMMM d")
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
                opacity: 1
            }
        }
        
        // 2. Bloco de Weather com fundo
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 300
            Layout.preferredHeight: weatherContent.implicitHeight + 30
            Layout.bottomMargin: 25
            color: "transparent"
            radius: Appearance.rounding.normal
            
            ColumnLayout {
                id: weatherContent
                anchors.centerIn: parent
                spacing: 10
                
                // Cidade com ícone de localização
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    
                    MaterialSymbol {
                        text: "location_on"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer2
                        opacity: 0.7
                    }
                    
                    StyledText {
                        text: Weather.data.city
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer2
                        opacity: 0.7
                    }
                }
                
                // Ícone do weather e temperatura, grandes no meio
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 15
                    
                    MaterialSymbol {
                        text: Weather.getWeatherIcon(Weather.data.condition)
                        iconSize: Appearance.font.pixelSize.huge * 2
                        color: Appearance.colors.colPrimary
                    }
                    
                    StyledText {
                        text: Weather.data.temp
                        font.pixelSize: Appearance.font.pixelSize.huge * 2
                        //font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer2
                    }
                }
                
                // Demais informações do clima
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 15
                    
                    RowLayout {
                        spacing: 4
                        MaterialSymbol {
                            text: "humidity_low"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                            opacity: 0.7
                        }
                        StyledText {
                            text: Weather.data.humidity
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                            opacity: 0.7
                        }
                    }
                    
                    RowLayout {
                        spacing: 4
                        MaterialSymbol {
                            text: "air"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                            opacity: 0.7
                        }
                        StyledText {
                            text: Weather.data.windSpeed
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                            opacity: 0.7
                        }
                    }
                    
                    RowLayout {
                        spacing: 4
                        MaterialSymbol {
                            text: "rainy"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                            opacity: 0.7
                        }
                        StyledText {
                            text: Weather.data.precipitation
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                            opacity: 0.7
                        }
                    }
                }
                
                // Nascer e pôr do sol
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 25
                    
                    RowLayout {
                        spacing: 6
                        MaterialSymbol {
                            text: "wb_twilight"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                            opacity: 0.7
                        }
                        StyledText {
                            text: Weather.data.sunrise
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                            opacity: 0.7
                        }
                    }
                    
                    RowLayout {
                        spacing: 6
                        MaterialSymbol {
                            text: "bedtime"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                            opacity: 0.7
                        }
                        StyledText {
                            text: Weather.data.sunset
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                            opacity: 0.7
                        }
                    }
                }
                
                // Fase da lua (linha própria)
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    
                    MaterialSymbol {
                        text: Weather.getMoonPhase().icon
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer2
                        opacity: 0.7
                    }
                    StyledText {
                        text: Weather.getMoonPhase().name
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer2
                        opacity: 0.7
                    }
                }
            }
        }
        
        // 3. Relógio com ícone
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            
            MaterialSymbol {
                text: "schedule"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnLayer1
            }
            
            StyledText {
                id: timeText
                text: {
                    const format = Config.options?.time?.format ?? "hh:mm";
                    let withSeconds;
                    if (format.includes(" AP")) {
                        withSeconds = format.replace(" AP", ":ss AP");
                    } else if (format.includes(" ap")) {
                        withSeconds = format.replace(" ap", ":ss ap");
                    } else {
                        withSeconds = format + ":ss";
                    }
                    return Qt.locale().toString(new Date(), withSeconds);
                }
                font.pixelSize: Appearance.font.pixelSize.huge * 1.2
                //font.weight: Font.Bold
                color: Appearance.colors.colOnLayer1
            }
        }
    }
    
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            const format = Config.options?.time?.format ?? "hh:mm";
            let withSeconds;
            if (format.includes(" AP")) {
                withSeconds = format.replace(" AP", ":ss AP");
            } else if (format.includes(" ap")) {
                withSeconds = format.replace(" ap", ":ss ap");
            } else {
                withSeconds = format + ":ss";
            }
            timeText.text = Qt.locale().toString(now, withSeconds);
            dateText.text = Qt.locale().toString(now, "dddd, MMMM d");
        }
    }
}