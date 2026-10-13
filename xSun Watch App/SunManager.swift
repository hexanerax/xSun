//
//  SunManager.swift
//  xSun Watch App
//
//  Created by Shubhankar Singh on 6/7/26.
//

import Foundation
import CoreLocation
import Combine
import Solar

enum TimeOfDay {
    case night
    case sunrise
    case day
    case sunset
}

class SunManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    // Location
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var locationAvailable: Bool = false
    @Published var cityName: String = ""
    
    // Solar data
    @Published var sunriseTime: Date? = nil
    @Published var sunsetTime: Date? = nil
    @Published var sunriseAzimuth: Double = 0.0
    @Published var sunsetAzimuth: Double = 0.0
    @Published var currentAzimuth: Double = 0.0
    @Published var currentElevation: Double = 0.0
    @Published var sunAngleOnArc: Double = 0.0
    @Published var arcRotation: Double = 0.0
    @Published var irradiance: Double = 0.0  // W/m²
    
    @Published var solarNoonTime: Date? = nil
    @Published var sunriseAngleOnArc: Double = 0.0
    @Published var peakAngleOnArc: Double = 0.0
    @Published var sunsetAngleOnArc: Double = 0.0
    
    @Published var isRising: Bool = true
    
    @Published var noonElevation: Double = 0.0   // sun's elevation at solar noon
    
    var dayProgress: Double {
        guard let sunrise = sunriseTime, let sunset = sunsetTime else { return 0.5 }
        let total = sunset.timeIntervalSince(sunrise)
        guard total > 0 else { return 0.5 }
        return displayDate.timeIntervalSince(sunrise) / total   // <0 or >1 at night; view clamps
    }
    
    //Time props
    @Published var timeOfDay: TimeOfDay = .day
    
    //Crown offset
    @Published var timeOffset: TimeInterval = 0.0  // seconds offset from now
    
    var displayDate: Date {
        Date().addingTimeInterval(timeOffset)
    }
    
    func resetToNow() {
        timeOffset = 0.0
        updateSolarData()
    }
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        // Refresh solar data every 60 seconds
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateSolarData()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.locationAvailable = true
            self.updateSolarData()
        }
        
        // Reverse geocode for city name
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            if let city = placemarks?.first?.locality {
                DispatchQueue.main.async {
                    self?.cityName = city
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func updateSolarData() {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let now = displayDate
        
        guard let solar = Solar(for: now, coordinate: coordinate) else { return }
        
        // Sunrise / Sunset times
        sunriseTime = solar.sunrise
        sunsetTime = solar.sunset
        
        // Calculate azimuth and elevation
        let (azimuth, elevation) = calculateSunPosition(
            date: now,
            latitude: latitude,
            longitude: longitude
        )
        currentAzimuth = azimuth
        currentElevation = elevation
        
        // Calculate sunrise/sunset azimuths
        if let sunrise = solar.sunrise {
            let (sunriseAz, _) = calculateSunPosition(date: sunrise, latitude: latitude, longitude: longitude)
            sunriseAzimuth = sunriseAz
        }
        if let sunset = solar.sunset {
            let (sunsetAz, _) = calculateSunPosition(date: sunset, latitude: latitude, longitude: longitude)
            sunsetAzimuth = sunsetAz
        }
        
        
        // Arc mapping — angles reflect the true azimuth separation between
        // sunrise, solar noon, and sunset rather than being stretched onto a
        // fixed 180° span.
        sunriseAngleOnArc = 0.0
        sunsetAngleOnArc = angleOnArc(azimuth: sunsetAzimuth, from: sunriseAzimuth)
        sunAngleOnArc = angleOnArc(azimuth: currentAzimuth, from: sunriseAzimuth)

        solarNoonTime = calculateSolarNoon()

        if let noon = solarNoonTime {
            let (peakAz, peakElev) = calculateSunPosition(date: noon, latitude: latitude, longitude: longitude)
            peakAngleOnArc = angleOnArc(azimuth: peakAz, from: sunriseAzimuth)
            noonElevation = peakElev
        }

        // Compare elevation now vs 60 seconds ago to determine direction
        let (_, elevBefore) = calculateSunPosition(
            date: now.addingTimeInterval(-60),
            latitude: latitude,
            longitude: longitude
        )
        isRising = elevation >= elevBefore

        arcRotation = sunriseAzimuth - 90.0
        currentAzimuth = azimuth
        currentElevation = elevation
        irradiance = calculateIrradiance(elevation: elevation)
        timeOfDay = calculateTimeOfDay()
    }
    
    // Real angular offset of `azimuth` from `sunriseAz`, normalized to [0, 360).
    private func angleOnArc(azimuth: Double, from sunriseAz: Double) -> Double {
        var diff = (azimuth - sunriseAz).truncatingRemainder(dividingBy: 360.0)
        if diff < 0 { diff += 360.0 }
        return diff
    }

    private func calculateSunPosition(date: Date, latitude: Double, longitude: Double) -> (azimuth: Double, elevation: Double) {
        let calendar = Calendar.current
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let hour = Double(calendar.component(.hour, from: date))
        let minute = Double(calendar.component(.minute, from: date))
        let second = Double(calendar.component(.second, from: date))
        let timeZoneOffset = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600.0
        
        let decimalHour = hour + minute / 60.0 + second / 3600.0
        
        // Solar declination
        let declination = 23.45 * sin((360.0 / 365.0 * (dayOfYear - 81)) * .pi / 180.0)
        
        // Equation of time (minutes)
        let b = (360.0 / 365.0 * (dayOfYear - 81)) * .pi / 180.0
        let eot = 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b)
        
        // Solar time
        let solarTime = decimalHour + (eot / 60.0) + (longitude / 15.0) - timeZoneOffset
        
        // Hour angle
        let hourAngle = (solarTime - 12.0) * 15.0
        
        let latRad = latitude * .pi / 180.0
        let decRad = declination * .pi / 180.0
        let haRad = hourAngle * .pi / 180.0
        
        // Elevation
        let sinElevation = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
        let elevation = asin(sinElevation) * 180.0 / .pi
        
        // Azimuth
        // Azimuth using atan2 for continuous values
        let x = sin(decRad) * cos(latRad) - cos(decRad) * sin(latRad) * cos(haRad)
        let y = -cos(decRad) * sin(haRad)
        var azimuth = atan2(y, x) * 180.0 / .pi
        
        // Normalize to 0-360
        if azimuth < 0 {
            azimuth += 360.0
        }
        
        return (azimuth, elevation)
    }
    
    private func calculateIrradiance(elevation: Double) -> Double {
        // No sunlight below the horizon
        guard elevation > 0 else { return 0.0 }
        
        let elevationRad = elevation * .pi / 180.0
        
        // Clear sky model using air mass
        // Solar constant ~1361 W/m²
        let solarConstant = 1361.0
        
        // Air mass approximation (Kasten & Young 1989)
        let airMass = 1.0 / (sin(elevationRad) + 0.50572 * pow(elevation + 6.07995, -1.6364))
        
        // Atmospheric extinction factor
        let irradiance = solarConstant * 0.7 * pow(0.678, airMass)
        
        return max(0, irradiance)
    }
    
    private func calculateTimeOfDay() -> TimeOfDay {
        guard let sunrise = sunriseTime, let sunset = sunsetTime else { return .day }
        
        let now = displayDate
        let sunriseMinus30 = sunrise.addingTimeInterval(-90 * 60)
        let sunrisePlus30 = sunrise.addingTimeInterval(90 * 60)
        let sunsetMinus30 = sunset.addingTimeInterval(-90 * 60)
        let sunsetPlus30 = sunset.addingTimeInterval(90 * 60)
        
        if now >= sunriseMinus30 && now <= sunrisePlus30 {
            return .sunrise
        } else if now >= sunsetMinus30 && now <= sunsetPlus30 {
            return .sunset
        } else if now > sunrisePlus30 && now < sunsetMinus30 {
            return .day
        } else {
            return .night
        }
    }
    
    private func calculateSolarNoon() -> Date? {
        guard let sunrise = sunriseTime, let sunset = sunsetTime else { return nil }
        let midpoint = sunrise.timeIntervalSince1970 + (sunset.timeIntervalSince1970 - sunrise.timeIntervalSince1970) / 2
        return Date(timeIntervalSince1970: midpoint)
    }
}
