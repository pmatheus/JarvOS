import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import "root:/modules/common/functions/color_utils.js" as ColorUtils
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

Item {
    id: weatherController
    
    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    property real widgetWidth: Appearance.sizes.mediaControlsWidth
    property real widgetHeight: Appearance.sizes.mediaControlsHeight * 1.5
    

    // Background shadow
    StyledRectangularShadow {
        target: backgroundRect
    }

    // Background
    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.windowRounding

        MouseArea {
            anchors.fill: parent
            onPressed: event => event.accepted = true
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 20
            }
            spacing: 15

            // Cidade com ícone de localização
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                
                MaterialSymbol {
                    text: "location_on"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                }
                
                StyledText {
                    text: Weather.data.city
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                }
            }
            
            // Ícone do weather e temperatura principais
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 15
                
                MaterialSymbol {
                    text: Weather.getWeatherIcon(Weather.data.condition)
                    iconSize: Appearance.font.pixelSize.huge * 1.5
                    color: Appearance.colors.colPrimary
                }
                
                StyledText {
                    text: Weather.data.temp
                    font.pixelSize: Appearance.font.pixelSize.huge * 1.5
                    //font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer1
                }
            }
            
            // Detalhes do clima - primeira linha (umidade, vento, precipitação)
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 15
                
                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "humidity_low"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                    StyledText {
                        text: Weather.data.humidity
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                }
                
                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "air"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                    StyledText {
                        text: Weather.data.windSpeed
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                }
                
                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "rainy"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                    StyledText {
                        text: Weather.data.precipitation
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
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
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                }
                StyledText {
                    text: Weather.getMoonPhase().name
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
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
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                    StyledText {
                        text: Weather.data.sunrise
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                }
                
                RowLayout {
                    spacing: 6
                    MaterialSymbol {
                        text: "bedtime"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                    StyledText {
                        text: Weather.data.sunset
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                    }
                }
            }
        }
    }
}