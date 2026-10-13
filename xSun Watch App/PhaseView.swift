//
//  PhaseView.swift
//  xSun Watch App
//
//  Created by Shubhankar Singh on 6/10/26.
//

import SwiftUI

struct PhaseView: View {
    @StateObject private var sunManager = SunManager()
    @State private var crownValue: Double = 0.0
    
    enum SunPhase: String {
        case astronomicalNightAscent = "NIGHT"
        case astronomicalNightDescent = "NIGHT "
        case nauticalTwilightAscent = "NAUTICAL TWILIGHT"
        case nauticalTwilightDescent = "NAUTICAL TWILIGHT "
        case civilTwilightAscent = "CIVIL TWILIGHT"
        case civilTwilightDescent = "CIVIL TWILIGHT "
        case firstLight = "FIRST LIGHT"
        case goldenHourSunrise = "GOLDEN HOUR"
        case day = "DAY"
        case goldenHourSunset = "GOLDEN HOUR "
        case lastLight = "LAST LIGHT"
    }
    
    var detailedPhase: SunPhase {
        let e = sunManager.currentElevation
        let rising = sunManager.isRising
        
        switch e {
        case ..<(-18):
            return rising ? .astronomicalNightAscent : .astronomicalNightDescent
        case -18 ..< -12:
            return rising ? .nauticalTwilightAscent : .nauticalTwilightDescent
        case -12 ..< -6:
            return rising ? .civilTwilightAscent : .civilTwilightDescent
        case -6 ..< -4:
            return rising ? .firstLight : .lastLight
        case -4 ..< 6:
            return rising ? .goldenHourSunrise : .goldenHourSunset
        default:
            return .day
        }
    }
    
    var phaseLabel: String {
        detailedPhase.rawValue
    }
    
    struct GraphLayout {
        let horizonY: CGFloat
        let maxRise: CGFloat
        let nightDepth: CGFloat
        let hMargin: CGFloat
    }
    
    func layout(for size: CGSize) -> GraphLayout {
        let amplitude = size.height * 0.25
        let centerY   = size.height * 0.55
        return GraphLayout(horizonY: centerY,
                           maxRise: amplitude,
                           nightDepth: amplitude,
                           hMargin: 0)
    }
    
    var backgroundGradient: LinearGradient {
        switch sunManager.timeOfDay {
        case .night:
            return LinearGradient(
                colors: [Color(red: 4/255, green: 27/255, blue: 47/255),
                         Color(red: 15/255, green: 33/255, blue: 84/255)],
                startPoint: .top, endPoint: .bottom)
        case .sunrise:
            return LinearGradient(
                colors: [Color(red: 228/255, green: 191/255, blue: 206/255),
                         Color(red: 214/255, green: 187/255, blue: 220/255)],
                startPoint: .top, endPoint: .bottom)
        case .day:
            return LinearGradient(
                colors: [Color(red: 36/255, green: 143/255, blue: 244/255),
                         Color(red: 153/255, green: 190/255, blue: 229/255)],
                startPoint: .top, endPoint: .bottom)
        case .sunset:
            return LinearGradient(
                colors: [Color(red: 58/255, green: 67/255, blue: 173/255),
                         Color(red: 255/255, green: 135/255, blue: 128/255)],
                startPoint: .top, endPoint: .bottom)
        }
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: sunManager.displayDate)
    }
    
    var timeOffsetLabel: String {
        let totalMinutes = Int(abs(crownValue))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if crownValue == 0 {
            return "NOW"
        }
        
        let timeString = hours > 0
        ? (minutes > 0 ? "\(hours)H \(minutes)M" : "\(hours)H")
        : "\(minutes)M"
        
        return crownValue > 0 ? "IN \(timeString)" : "\(timeString) AGO"
    }
    
    func dayFraction(_ date: Date) -> CGFloat {
        let start = Calendar.current.startOfDay(for: date)
        return CGFloat(date.timeIntervalSince(start) / 86400.0)
    }
    
    // wraps the noon-relative offset into -0.5...0.5 (-12h...+12h)
    func wrappedOffset(for f: CGFloat, fNoon: CGFloat) -> CGFloat {
        var offset = f - fNoon
        if offset < -0.5 { offset += 1 }
        if offset > 0.5  { offset -= 1 }
        return offset
    }
    
    // y for any fraction of the day, relative to solar noon (cos is periodic, so f can be outside 0...1)
    func curveY(at f: CGFloat, _ l: GraphLayout) -> CGFloat {
        guard let sr = sunManager.sunriseTime, let ss = sunManager.sunsetTime else {
            return l.horizonY
        }
        let fSunrise = dayFraction(sr)
        let fSunset  = dayFraction(ss)
        let Lday   = max(0.01, min(0.99, fSunset - fSunrise))
        let Lnight = 1 - Lday
        
        let factor = CGFloat(max(0, min(sunManager.noonElevation, 90)) / 90.0)
        let Aday   = l.maxRise * factor
        let k      = Aday / Lday
        let Anight = k * Lnight
        
        if f >= fSunrise && f <= fSunset {
            let t = (f - fSunrise) / Lday
            return l.horizonY - Aday * sin(.pi * t)
        } else {
            let tn: CGFloat
            if f > fSunset {
                tn = (f - fSunset) / Lnight
            } else {
                tn = ((1 - fSunset) + f) / Lnight
            }
            return l.horizonY + Anight * sin(.pi * tn)
        }
    }
    
    // path sampled across a 24h window CENTERED on solar noon
    func sunPath(size: CGSize, _ l: GraphLayout, fNoon: CGFloat) -> Path {
        Path { p in
            let steps = 120
            for i in 0...steps {
                let offset = CGFloat(i) / CGFloat(steps) - 0.5
                let f = wrap01(fNoon + offset)
                let x = l.hMargin + (offset + 0.5) * (size.width - l.hMargin * 2)
                let y = curveY(at: f, l)
                let pt = CGPoint(x: x, y: y)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
        }
    }
    
    func horizonPath(size: CGSize, _ l: GraphLayout) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: l.horizonY))
            p.addLine(to: CGPoint(x: size.width, y: l.horizonY))
        }
    }
    
    func markerPositions(size: CGSize, _ l: GraphLayout, segments: Int) -> [(x: CGFloat, label: String)] {
        let padding: CGFloat = 16
        return (0...segments).map { i in
            let fraction = CGFloat(i) / CGFloat(segments)
            let x = padding + fraction * (size.width - padding * 2)
            let hour = Int(round(fraction * 24))
            return (x, "\(hour)")
        }
    }
    
    
    
    func markersPath(size: CGSize, _ l: GraphLayout, anchorY: CGFloat, segments: Int) -> Path {
        Path { p in
            let lineHeight: CGFloat = 42
            let topY = anchorY - lineHeight / 2
            let bottomY = anchorY + lineHeight / 2
            for marker in markerPositions(size: size, l, segments: segments) {
                p.move(to: CGPoint(x: marker.x, y: topY))
                p.addLine(to: CGPoint(x: marker.x, y: bottomY))
            }
        }
    }
    
    func wrap01(_ x: CGFloat) -> CGFloat {
        let r = x.truncatingRemainder(dividingBy: 1)
        return r < 0 ? r + 1 : r
    }
    
    var body: some View {
        NavigationStack{
            GeometryReader { geo in
                let l = layout(for: geo.size)
                let fNoon = sunManager.solarNoonTime.map(dayFraction) ?? 0.5
                
                // current time as an offset from solar noon, wrapped to -0.5...0.5 (-12h...+12h)
                let f = dayFraction(sunManager.displayDate)
                let offset = wrappedOffset(for: f, fNoon: fNoon)
                
                let sunX = l.hMargin + (offset + 0.5) * (geo.size.width - l.hMargin * 2)
                let sunY = curveY(at: f, l)
                let sunPt = CGPoint(x: sunX, y: sunY)
                
                let markerAnchorY = l.horizonY - l.maxRise * 0.60
                
                //BG + Markers
                ZStack {
                    backgroundGradient
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.3), value: sunManager.timeOfDay)
                    
                    ForEach(markerPositions(size: geo.size, l, segments: 4), id: \.label) { marker in
                        let lineHeight: CGFloat = 42
                        RoundedRectangle(cornerRadius: 999)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(1.0), .white.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 1.5, height: lineHeight)
                            .position(x: marker.x, y: markerAnchorY)
                            .blendMode(.softLight)
                    }
                    
                    ForEach(markerPositions(size: geo.size, l, segments: 4), id: \.label) { marker in
                        Text(marker.label)
                            .font(.system(size: 12, design: .rounded).weight(.semibold))
                            .foregroundColor(.white.opacity(1))
                            .position(x: marker.x, y: markerAnchorY - 34)
                            .blendMode(.softLight)
                    }
                    
                }
                
                
                //Shadow
                ZStack {
                    sunPath(size: geo.size, l, fNoon: fNoon)
                        .stroke(.black.opacity(0.30), lineWidth: 2.5)
                        .blur(radius: 4)
                }
                .offset(y: 12)
                
                //Horizon + Sun Path + Sun/Moon Sprite
                ZStack {
                    
                    horizonPath(size: geo.size, l)
                        .stroke(.white.opacity(1), lineWidth: 1)
                        .blendMode(.softLight)
                    
                    sunPath(size: geo.size, l, fNoon: fNoon)
                        .stroke(Color(.white),lineWidth: 2.5)
                    
                    Image(sunY <= l.horizonY ? "sun_small" : "moon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .animation(.easeInOut(duration: 0.1), value: sunY <= l.horizonY)
                        .position(sunPt)
                }
                
                ZStack {
                    VStack(spacing: -4){
                        Text(phaseLabel)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .blendMode(.plusLighter)
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: geo.size.width, alignment: .center)
                            .lineSpacing(-2)
                        
                        Text(timeString)
                            .font(.system(size: 42, design: .rounded).weight(.medium))
                            .foregroundColor(.white)
                            .frame(width:geo.size.width, alignment: .center)
                            .lineSpacing(-2)
                        
                        Text(timeOffsetLabel)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .blendMode(.plusLighter)
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: geo.size.width, alignment: .center)
                            .lineSpacing(-2)
                        
                    }
                    .padding(.top, 125)
                    
                    HStack(spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "sunrise.fill")
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 10).weight(.semibold))
                                .opacity(1.0)
                            Text(sunManager.sunriseTime?.formatted(date: .omitted, time: .shortened) ?? "--:--")
                                .font(.system(size: 12, design: .rounded).weight(.semibold))
                        }
                        
                        HStack(spacing: 3) {
                            Image(systemName: "sunset.fill")
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 10).weight(.semibold))
                                .opacity(1.0)
                            Text(sunManager.sunsetTime?.formatted(date: .omitted, time: .shortened) ?? "--:--")
                                .font(.system(size: 12, design: .rounded).weight(.semibold))
                        }
                    }
                    .padding(.top, 225)
                }
                
                ZStack {
                    Text(sunManager.cityName.isEmpty ? " " : sunManager.cityName.uppercased())
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.trailing, 16)
                        .frame(width: geo.size.width, alignment: .trailing)
                        .padding(.top,36)
                }            }
            .ignoresSafeArea()
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            crownValue = 0.0
                            sunManager.resetToNow()
                        }
                    }) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    PhaseView()
}
