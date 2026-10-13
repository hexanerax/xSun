//
//  ContentView.swift
//  xSun Watch App
//
//  Created by Shubhankar Singh on 6/4/26.
//

import SwiftUI
import CoreLocation
import Combine
import MapKit

////COMPASS MANAGER
class CompassManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var heading: Double = 0.0
    private var previousHeading: Double = 0.0
    private var totalRotation: Double = 0.0
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            let newH = newHeading.magneticHeading
            var delta = newH - self.previousHeading
            
            // Take the shortest path
            if delta > 180 {
                delta -= 360
            } else if delta < -180 {
                delta += 360
            }
            
            self.totalRotation += delta
            self.previousHeading = newH
            self.heading = self.totalRotation
        }
    }
}

////Gradients for the time of the day

struct DirectionView: View {
    @StateObject private var compass = CompassManager()
    @StateObject private var sunManager = SunManager()
    @State private var crownValue: Double = 0.0
    @State private var compassEnabled: Bool = true
    @State private var mapEnabled: Bool = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    private var mapCenter: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: sunManager.latitude, longitude: sunManager.longitude)
    }
    
    private func updateCamera() {
        guard mapEnabled else { return }
        let camera = MapCamera(
            centerCoordinate: mapCenter,
            distance: 2000,                 // zoom level — tune to taste
            heading: compassEnabled ? compass.heading : 0,
            pitch: 0
        )
        cameraPosition = .camera(camera)
    }
    
    var backgroundGradient: LinearGradient {
        switch sunManager.timeOfDay {
        case .night:
            return LinearGradient(
                colors: [Color(red: 4/255, green: 27/255, blue: 47/255), Color(red: 15/255, green: 33/255, blue: 84/255)],
                startPoint: .top, endPoint: .bottom
            )
        case .sunrise:
            return LinearGradient(
                colors: [Color(red: 228/255, green: 191/255, blue: 206/255), Color(red: 214/255, green: 187/255, blue: 220/255)],
                startPoint: .top, endPoint: .bottom
            )
        case .day:
            return LinearGradient(
                colors: [Color(red: 36/255, green: 143/255, blue: 244/255), Color(red: 153/255, green: 190/255, blue: 229/255)],
                startPoint: .top, endPoint: .bottom
            )
        case .sunset:
            return LinearGradient(
                colors: [Color(red: 58/255, green: 67/255, blue: 173/255), Color(red: 255/255, green: 135/255, blue: 128/255)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
    
    var arcColor: Color {
        sunManager.currentElevation >= 0
        ? Color(red: 255/255, green: 255/255, blue: 0/255)    // yellow for day
        : Color(red: 155/255, green: 202/255, blue: 244/255)   // light blue for night
    }
    
    var indicatorColor: Color {
        sunManager.currentElevation >= 0
        ? Color(red: 255/255, green: 255/255, blue: 0/255)
        : Color(red: 155/255, green: 202/255, blue: 244/255)
    }
    
    var markerColor: Color {
        sunManager.currentElevation >= 0
        ? Color(red: 255/255, green: 255/255, blue: 0/255)
        : Color(red: 155/255, green: 202/255, blue: 244/255)
    }
    
    // Time formatter
    var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }
    
    var body: some View {
        
        // Sun data
        let sunAngleOnArc = sunManager.sunAngleOnArc
        let arcRotation = sunManager.arcRotation
        
        NavigationStack{
            ZStack {
                if mapEnabled {
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                    }
                    .mapStyle(.standard)
                    .ignoresSafeArea()
                } else {
                    backgroundGradient
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.3), value: sunManager.timeOfDay)
                }
                
                GeometryReader{ geometry in
                    VStack(spacing:5){
                        Spacer().frame(height: 20)
                        ZStack {
                            
                            //Base Circle
                            Circle()
                                .stroke(Color.init(red: 190/255, green: 190/255, blue: 190/255), lineWidth: 24)
                                .blendMode(mapEnabled ? .normal : .softLight)
                                .opacity(mapEnabled ? 0.3 : 1.0)
                            
                            //NESW Indicators
                            ForEach(["N", "E", "S", "W"].indices, id: \.self) { index in
                                let angle = Double(index) * 90.0
                                let radians = (angle - 90) * .pi / 180
                                let radius = (geometry.size.width * 0.8) / 2
                                
                                Text(["N", "E", "S", "W"][index])
                                    .font(.system(size: 15, design: .rounded).weight(.medium))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(angle))
                                    .offset(
                                        x: CGFloat(cos(radians) * radius),
                                        y: CGFloat(sin(radians) * radius)
                                    )
                            }
                            
                            ZStack{
                                //Arc — solid through the day, fading out just past sunset and fading back in just before sunrise
                                let fadeWidth = 15.0 / 360.0
                                let sunsetLoc = min(max(sunManager.sunsetAngleOnArc / 360.0, fadeWidth), 1.0 - fadeWidth)
                                let fadeOutEnd = sunsetLoc + fadeWidth
                                let fadeInStart = max(fadeOutEnd, 1.0 - fadeWidth)

                                Path { path in
                                    path.addArc(
                                        center: CGPoint(x: geometry.size.width * 0.4 , y: geometry.size.height * 0.4 - 10),
                                        radius: geometry.size.width * 0.4,
                                        startAngle: .degrees(0.0),
                                        endAngle: .degrees(360.0),
                                        clockwise: false
                                    )
                                }
                                .stroke(AngularGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: arcColor, location: 0.0),
                                        .init(color: arcColor, location: sunsetLoc),
                                        .init(color: arcColor.opacity(0.0), location: fadeOutEnd),
                                        .init(color: arcColor.opacity(0.0), location: fadeInStart),
                                        .init(color: arcColor, location: 1.0)
                                    ]),
                                    center: .center
                                ), lineWidth: 3)

                                //Arc Markers — evenly spaced between the real sunrise and sunset angles
                                let markerSpan = sunManager.sunsetAngleOnArc - sunManager.sunriseAngleOnArc
                                let markerInset = markerSpan * 0.08
                                ForEach(0..<10, id: \.self) { index in
                                    let t = Double(index) / 9.0
                                    let angle = sunManager.sunriseAngleOnArc + markerInset + t * (markerSpan - 2 * markerInset)
                                    let arcCenterX = geometry.size.width * 0.4
                                    let arcCenterY = geometry.size.height * 0.4 - 10
                                    let arcRadius = geometry.size.width * 0.4
                                    let zStackCenter = geometry.size.width * 0.4
                                    let radians = angle * .pi / 180

                                    Circle()
                                        .fill(markerColor)
                                        .frame(width: 6, height: 6)
                                        .offset(
                                            x: arcCenterX + CGFloat(cos(radians) * arcRadius) - zStackCenter,
                                            y: arcCenterY + CGFloat(sin(radians) * arcRadius) - zStackCenter
                                        )
                                }
                                
                                //Capsule Indicators
                                let indicators: [(angle: Double, icon: String)] = [
                                    (sunManager.sunriseAngleOnArc + 15.0, "sunrise.fill"),
                                    (sunManager.peakAngleOnArc, "sun.max.fill"),
                                    (sunManager.sunsetAngleOnArc - 15.0, "sunset.fill")
                                ]
                                
                                ForEach(indicators, id: \.angle) { indicator in
                                    let arcCenterX = geometry.size.width * 0.4
                                    let arcCenterY = geometry.size.height * 0.4 - 10
                                    let arcRadius = geometry.size.width * 0.4
                                    let zStackCenter = geometry.size.width * 0.4
                                    let radians = (indicator.angle) * .pi / 180
                                    
                                    ZStack {
                                        Circle()
                                            .fill(indicatorColor)
                                            .frame(width: 18, height: 18)
                                        Image(systemName: indicator.icon)
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundColor(.black)
                                            .opacity(0.7)
                                    }
                                    .rotationEffect(.degrees(-arcRotation + (compassEnabled ? compass.heading : 0)))
                                    .offset(
                                        x: arcCenterX + CGFloat(cos(radians) * arcRadius) - zStackCenter,
                                        y: arcCenterY + CGFloat(sin(radians) * arcRadius) - zStackCenter
                                    )
                                }
                                
                                // Sun Position Indicator
                                let sunRadians = (sunAngleOnArc) * .pi / 180
                                let arcCenterX = geometry.size.width * 0.4
                                let arcCenterY = geometry.size.height * 0.4 - 10
                                let arcRadius = geometry.size.width * 0.4
                                let zStackCenter = geometry.size.width * 0.4
                                
                                Image(sunManager.currentElevation >= 0 ? "sun_small" : "moon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .animation(.easeInOut(duration: 0.3), value: sunManager.currentElevation >= 0)
                                    .rotationEffect(.degrees(arcRotation))
                                    .offset(
                                        x: arcCenterX + CGFloat(cos(sunRadians) * arcRadius) - zStackCenter,
                                        y: arcCenterY + CGFloat(sin(sunRadians) * arcRadius) - zStackCenter
                                    )
                            }
                            .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                            .rotationEffect(.degrees(arcRotation))
                            .animation(.easeInOut(duration: 0.5), value: sunManager.currentElevation >= 0)
                            
                        }
                        .rotationEffect(.degrees(compassEnabled ? -compass.heading : 0))
                        .animation(.easeInOut(duration: 0.2), value: compass.heading)
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                        
                        Spacer().frame(height: 5)
                        HStack{
                            Image(systemName: "sun.min.fill").font(.system(size: 12))
                                .opacity(mapEnabled ? 0.0 : 0.5)
                            Text("\(Int(sunManager.irradiance)) W/m²")
                                .font(.system(size: 12, design: .rounded).weight(.medium))
                                .opacity(mapEnabled ? 0.0 : 1.0)
                            
                            Image(systemName: "sunset.fill").font(.system(size: 12))
                                .opacity(mapEnabled ? 0.0 : 0.5)
                            Text(sunManager.sunsetTime?.formatted(date: .omitted, time: .shortened) ?? "--:--")
                                .font(.system(size: 12, design: .rounded).weight(.medium))
                                .opacity(mapEnabled ? 0.0 : 1.0)
                        }
                        Spacer().frame(height: 3)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                VStack{
                    Image("arrow")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .padding(.bottom, -15)
                    VStack{
                        Text("\(Int(sunManager.currentAzimuth))°")
                            .font(.system(size: 32, design: .rounded).weight(.medium))
                        Text("AZIMUTH")
                            .font(.system(size: 12, design: .rounded).weight(.semibold))
                            .opacity(0.6)
                    }
                    Spacer().frame(height: 2)
                    VStack{
                        Text("\(Int(sunManager.currentElevation))°")
                            .font(.system(size: 32, design: .rounded).weight(.medium))
                        Text("ELEVATION")
                            .font(.system(size: 12, design: .rounded).weight(.semibold))
                            .opacity(0.6)
                    }
                }
                .padding(.bottom, 50)
                .opacity(mapEnabled ? 0 : 1)
                .contentShape(Rectangle())
                .onTapGesture {
                    crownValue = 0.0
                    sunManager.resetToNow()
                }
            }
            .focusable()
            .digitalCrownRotation(
                $crownValue,
                from: -720,
                through: 720,
                sensitivity: .high,
                isContinuous: true,
                isHapticFeedbackEnabled: true
            )
            .onChange(of: crownValue) { oldValue, newValue in
                sunManager.timeOffset = newValue * 60
                sunManager.updateSolarData()
            }
            .onChange(of: sunManager.latitude) { _, _ in
                updateCamera()
            }
            .onChange(of: compass.heading) { _, _ in
                updateCamera()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        compassEnabled.toggle()
                    }) {
                        Image(systemName: compassEnabled ? "location.north.line.fill" : "location.north.line")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        mapEnabled.toggle()
                        if mapEnabled { updateCamera() }
                    }) {
                        Image(systemName: mapEnabled ? "map.fill" : "map")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

