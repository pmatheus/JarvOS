pragma Singleton
import "root:/modules/common"
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    
    readonly property int fetchInterval: (Config.options?.bar?.weather?.fetchInterval || 10) * 60 * 1000
    readonly property string city: Config.options?.bar?.weather?.city || "Brasilia"
    readonly property bool useUSCS: Config.options?.bar?.weather?.useUSCS || false
    
    property var data: ({
        temp: "--",
        condition: "clear_day",
        humidity: "--",
        windSpeed: "--",
        precipitation: "--",
        sunrise: "--",
        sunset: "--",
        city: "Loading..."
    })
    
    function refineData(rawData) {
        let temp = {};
        const current = rawData?.current_condition?.[0];
        const location = rawData?.nearest_area?.[0];
        const astronomy = rawData?.weather?.[0]?.astronomy?.[0];
        
        if (root.useUSCS) {
            temp.temp = (current?.temp_F || "--") + "°F";
            temp.windSpeed = (current?.windspeedMiles || "--") + " mph";
            temp.precipitation = (current?.precipInches || "--") + " in";
        } else {
            temp.temp = (current?.temp_C || "--") + "°C";
            temp.windSpeed = (current?.windspeedKmph || "--") + " km/h";
            temp.precipitation = (current?.precipMM || "--") + " mm";
        }
        temp.condition = current?.weatherCode || "113";
        temp.humidity = (current?.humidity || "--") + "%";
        temp.sunrise = root.formatTime(astronomy?.sunrise || "--");
        temp.sunset = root.formatTime(astronomy?.sunset || "--");
        temp.city = location?.areaName?.[0]?.value || root.city;
        
        console.log(`[Weather] Updated: ${temp.temp}, ${temp.city}, ${temp.condition}`);
        root.data = temp;
    }
    
    function fetchWeather() {
        const formattedCity = root.city.trim().split(/\s+/).join('+');
        const command = `curl -s "wttr.in/${formattedCity}?format=j1"`;
        
        console.log(`[Weather] Fetching weather for: ${formattedCity}`);
        weatherFetcher.command[2] = command;
        weatherFetcher.running = true;
    }
    
    readonly property var weatherIcons: ({
        "113": { day: "clear_day", night: "clear_night" },      // Sunny/Clear
        "116": { day: "partly_cloudy_day", night: "partly_cloudy_night" }, // Partly cloudy
        "119": "cloud",          // Cloudy
        "122": "cloud",          // Overcast
        "143": "foggy",          // Mist
        "176": "rainy",          // Patchy rain
        "200": "thunderstorm",   // Thundery outbreaks
        "230": "snowing_heavy",  // Blizzard
        "248": "foggy",          // Fog
        "263": "rainy",          // Patchy light drizzle
        "266": "rainy",          // Light drizzle
        "296": "rainy",          // Light rain
        "302": "weather_hail",   // Moderate rain
        "308": "weather_hail",   // Heavy rain
        "320": "cloudy_snowing", // Light sleet
        "323": "snowing",        // Light snow
        "326": "cloudy_snowing", // Moderate sleet
        "329": "snowing_heavy",  // Moderate snow
        "332": "snowing_heavy",  // Heavy snow
        "386": "thunderstorm",   // Thunder
        "395": "snowing"         // Heavy snow showers
    })
    
    function isNightTime() {
        const now = new Date();
        const currentHour = now.getHours();
        const currentMinute = now.getMinutes();
        const currentTimeMinutes = currentHour * 60 + currentMinute;
        
        // Parse sunrise and sunset times
        const sunriseTime = parseTimeString(root.data.sunrise);
        const sunsetTime = parseTimeString(root.data.sunset);
        
        if (sunriseTime === null || sunsetTime === null) {
            // Fallback: consider night if between 18:00 and 06:00
            return currentHour >= 18 || currentHour < 6;
        }
        
        // Check if current time is before sunrise or after sunset
        return currentTimeMinutes < sunriseTime || currentTimeMinutes >= sunsetTime;
    }
    
    function parseTimeString(timeStr) {
        if (!timeStr || timeStr === "--") return null;
        
        // Parse time in format "HH:mm" or "H:mm"
        const match = timeStr.match(/(\d{1,2}):(\d{2})/);
        if (!match) return null;
        
        const hours = parseInt(match[1]);
        const minutes = parseInt(match[2]);
        return hours * 60 + minutes;
    }
    
    function getWeatherIcon(code) {
        const iconData = weatherIcons[code];
        
        if (!iconData) return "cloud";
        
        // If iconData is a string, return it directly (no day/night variants)
        if (typeof iconData === "string") return iconData;
        
        // If iconData is an object with day/night variants
        if (typeof iconData === "object" && iconData.day && iconData.night) {
            return isNightTime() ? iconData.night : iconData.day;
        }
        
        return "cloud";
    }
    
    function formatTime(timeStr) {
        if (!timeStr || timeStr === "--") return timeStr;
        
        // Parse "06:15 AM" format from wttr.in
        const match = timeStr.match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
        if (!match) return timeStr;
        
        let hours = parseInt(match[1]);
        const minutes = match[2];
        const period = match[3].toUpperCase();
        
        // Convert to 24-hour format
        if (period === "AM" && hours === 12) hours = 0;
        else if (period === "PM" && hours !== 12) hours += 12;
        
        // Create a date with the parsed time
        const date = new Date();
        date.setHours(hours, parseInt(minutes), 0, 0);
        
        // Format using system config
        const format = Config.options?.time?.format ?? "hh:mm";
        return Qt.locale().toString(date, format);
    }
    
    function getMoonPhase() {
        const now = new Date();
        const year = now.getFullYear();
        const month = now.getMonth() + 1;
        const day = now.getDate();
        
        // Algoritmo simples para calcular fase da lua
        let c = Math.floor(year / 100);
        let e = 2 - c + Math.floor(c / 4);
        let jd = Math.floor(365.25 * (year + 4716)) + Math.floor(30.6001 * (month + 1)) + day + e - 1524.5;
        let daysSinceNew = (jd - 2451549.5) % 29.53;
        
        if (daysSinceNew < 0) daysSinceNew += 29.53;
        
        if (daysSinceNew < 1.84566) return { icon: "brightness_2", name: "New Moon" };
        else if (daysSinceNew < 5.53699) return { icon: "brightness_3", name: "Waxing Crescent" };
        else if (daysSinceNew < 9.22831) return { icon: "brightness_4", name: "First Quarter" };
        else if (daysSinceNew < 12.91963) return { icon: "brightness_5", name: "Waxing Gibbous" };
        else if (daysSinceNew < 16.61096) return { icon: "brightness_1", name: "Full Moon" };
        else if (daysSinceNew < 20.30228) return { icon: "brightness_4", name: "Waning Gibbous" };
        else if (daysSinceNew < 23.99361) return { icon: "brightness_3", name: "Last Quarter" };
        else if (daysSinceNew < 27.68493) return { icon: "brightness_2", name: "Waning Crescent" };
        else return { icon: "brightness_2", name: "New Moon" };
    }
    
    Process {
        id: weatherFetcher
        command: ["bash", "-c", ""]
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                
                console.log(`[Weather] Complete JSON received, length: ${text.length}`);
                try {
                    const parsedData = JSON.parse(text);
                    console.log(`[Weather] JSON parsed successfully`);
                    root.refineData(parsedData);
                } catch (e) {
                    console.error(`[Weather] Error parsing JSON: ${e.message}`);
                    console.error(`[Weather] Raw data: ${text.substring(0, 200)}...`);
                }
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.error(`[Weather] stderr: ${text}`);
                }
            }
        }
    }
    
    Timer {
        running: true
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: true
        onTriggered: root.fetchWeather()
    }
}