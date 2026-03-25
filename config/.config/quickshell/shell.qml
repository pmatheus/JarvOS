//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// Adjust this to make the shell smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import "./modules/common/"
import "./modules/backgroundWidgets/"
import "./modules/bar/"
import "./modules/calendarMonitor/"
import "./modules/cheatsheet/"
import "./modules/dock/"
import "./modules/mediaControls/"
import "./modules/notificationPopup/"
import "./modules/onScreenDisplay/"
import "./modules/onScreenKeyboard/"
import "./modules/overview/"
import "./modules/resourceMonitor/"
import "./modules/weatherMonitor/"
import "./modules/clockMonitor/"
import "./modules/screenCorners/"
import "./modules/session/"
import "./modules/sidebarRight/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import "./services/"

ShellRoot {
    // Enable/disable modules here. False = not loaded at all, so rest assured
    // no unnecessary stuff will take up memory if you decide to only use, say, the overview.
    property bool enableBar: true
    property bool enableBackgroundWidgets: true
    property bool enableCalendarMonitor: true
    property bool enableCheatsheet: true
    property bool enableDock: false
    property bool enableMediaControls: true
    property bool enableNotificationPopup: true
    property bool enableOnScreenDisplayBrightness: true
    property bool enableOnScreenDisplayVolume: true
    property bool enableOnScreenKeyboard: true
    property bool enableOverview: true
    property bool enableReloadPopup: true
    property bool enableResourceMonitor: true
    property bool enableWeatherMonitor: true
    property bool enableClockMonitor: true
    property bool enableScreenCorners: true
    property bool enableSession: true
    property bool enableSidebarRight: true

    // Force initialization of some singletons
    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        Cliphist.refresh()
        FirstRunExperience.load()
        Hyprsunset.load()
        Weather.fetchWeather()
    }

    LazyLoader { active: enableBar; component: Bar {} }
    LazyLoader { active: enableBackgroundWidgets; component: BackgroundWidgets {} }
    LazyLoader { active: enableCalendarMonitor; component: CalendarMonitor {} }
    LazyLoader { active: enableCheatsheet; component: Cheatsheet {} }
    LazyLoader { active: enableDock; component: Dock {} }
    LazyLoader { active: enableMediaControls; component: MediaControls {} }
    LazyLoader { active: enableNotificationPopup; component: NotificationPopup {} }
    LazyLoader { active: enableOnScreenDisplayBrightness; component: OnScreenDisplayBrightness {} }
    LazyLoader { active: enableOnScreenDisplayVolume; component: OnScreenDisplayVolume {} }
    LazyLoader { active: enableOnScreenKeyboard; component: OnScreenKeyboard {} }
    LazyLoader { active: enableOverview; component: Overview {} }
    LazyLoader { active: enableReloadPopup; component: ReloadPopup {} }
    LazyLoader { active: enableResourceMonitor; component: ResourceMonitor {} }
    LazyLoader { active: enableWeatherMonitor; component: WeatherMonitor {} }
    LazyLoader { active: enableClockMonitor; component: ClockMonitor {} }
    LazyLoader { active: enableScreenCorners; component: ScreenCorners {} }
    LazyLoader { active: enableSession; component: Session {} }
    LazyLoader { active: enableSidebarRight; component: SidebarRight {} }
}

