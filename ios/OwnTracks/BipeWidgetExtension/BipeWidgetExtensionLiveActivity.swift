//
//  BipeWidgetExtensionLiveActivity.swift
//  BipeWidgetExtension
//

import ActivityKit
import WidgetKit
import SwiftUI

private class WidgetBundleClass {}

@available(iOS 16.1, *)
struct DeviceBadgeView: View {
    let item: String
    let themeColor: Color
    
    var cleanName: String {
        let name = item.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasSuffix(".png") || name.hasSuffix(".svg") || name.hasSuffix(".jpg") {
            return (name as NSString).deletingPathExtension
        }
        return name
    }
    
    var isImageFile: Bool {
        item.contains(".") || UIImage(named: cleanName) != nil || UIImage(named: item) != nil
    }
    
    var uiImage: UIImage? {
        if let img = UIImage(named: cleanName) ?? UIImage(named: item) ?? UIImage(named: "drawable/\(cleanName)") ?? UIImage(named: "drawable/\(item)") {
            return img
        }
        
        let ext = (item as NSString).pathExtension
        let possibleTypes = Array(Set([ext, "png", "PNG", "jpg", "JPG", "jpeg"])).filter { !$0.isEmpty }
        let bundles = [Bundle.main, Bundle(for: WidgetBundleClass.self)]
        
        for bundle in bundles {
            for type in possibleTypes {
                // 1. Busca na raiz do bundle (Yellow Group no Xcode)
                if let path = bundle.path(forResource: cleanName, ofType: type), let img = UIImage(contentsOfFile: path) {
                    return img
                }
                if let path = bundle.path(forResource: item, ofType: type), let img = UIImage(contentsOfFile: path) {
                    return img
                }
                // 2. Busca na pasta drawable (Blue Folder Reference no Xcode)
                if let path = bundle.path(forResource: cleanName, ofType: type, inDirectory: "drawable"), let img = UIImage(contentsOfFile: path) {
                    return img
                }
                if let path = bundle.path(forResource: item, ofType: type, inDirectory: "drawable"), let img = UIImage(contentsOfFile: path) {
                    return img
                }
            }
        }
        
        return nil
    }
    
    var systemIcon: String {
        let n = cleanName.lowercased()
        if n.contains("bus") || n.contains("onibus") { return "bus.fill" }
        if n.contains("car") || n.contains("fiat") { return "car.fill" }
        if n.contains("bicycle") || n.contains("bike") { return "bicycle" }
        if n.contains("boat") || n.contains("ship") { return "ferry.fill" }
        if n.contains("plane") || n.contains("aviao") { return "airplane" }
        if n.contains("motorcycle") || n.contains("scooter") { return "motorcycle" }
        if n.contains("truck") || n.contains("caminhao") { return "truck.box.fill" }
        if n.contains("train") || n.contains("tram") { return "tram.fill" }
        return "mappin.circle.fill"
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [themeColor, themeColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 22, height: 22)
                    
                    Image(systemName: systemIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(2)
    }
}

// MARK: - View para Transições de Região ("transition") - Premium UI

@available(iOS 16.1, *)
struct TransitionWidgetView: View {
    let state: BipeAlertActivityAttributes.ContentState
    
    var isExit: Bool {
        let ev = state.event?.lowercased() ?? ""
        return ev.contains("exit") || ev.contains("saida") || ev.contains("saída")
    }
    
    var themeColor: Color {
        isExit ? Color.orange : Color(red: 0.18, green: 0.80, blue: 0.44) // Emerald Green vs Amber Orange
    }
    
    var eventTitle: String {
        isExit ? "SAIU" : "ENTROU"
    }
    
    var eventIcon: String {
        isExit ? "arrow.left.to.line.compact" : "arrow.right.to.line.compact"
    }
    
    var regionName: String {
        state.way ?? state.address
    }
    
    var devicesList: [String] {
        state.devices ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: 1. Header com ícone de radar, título da região e badge translúcido
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [themeColor.opacity(0.3), themeColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(themeColor.opacity(0.4), lineWidth: 1.5)
                        )
                    
                    if let triggerIcon = state.icon ?? state.iconUrl, !triggerIcon.isEmpty {
                        DeviceBadgeView(item: triggerIcon, themeColor: themeColor)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(themeColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(regionName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        // Live pulse dot
                        Circle()
                            .fill(themeColor)
                            .frame(width: 7, height: 7)
                            .shadow(color: themeColor, radius: 3)
                    }
                    
                    Text("MONITORAMENTO")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                }
                
                Spacer()
                
                // Badge translúcido
                HStack(spacing: 5) {
                    Image(systemName: eventIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(eventTitle)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(themeColor.opacity(0.18))
                )
                .overlay(
                    Capsule()
                        .stroke(themeColor.opacity(0.4), lineWidth: 1.2)
                )
                .foregroundColor(themeColor)
            }
            
            // MARK: 2. Card de Perímetro (Geofence Zone) com os dispositivos
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 5) {
                        Text(devicesList.isEmpty ? "PERÍMETRO ATIVO" : "DISPOSITIVOS NA ZONA")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                    }
                    
                    Spacer()
                    
                    if !devicesList.isEmpty {
                        Text("\(devicesList.count) \(devicesList.count == 1 ? "dispositivo" : "dispositivos")")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(themeColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(themeColor.opacity(0.12)))
                    }
                }
                
                if !devicesList.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(devicesList.prefix(4), id: \.self) { devName in
                            DeviceBadgeView(item: devName, themeColor: themeColor)
                        }
                        
                        if devicesList.count > 4 {
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                Text("+\(devicesList.count - 4)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(themeColor)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 13))
                            .foregroundColor(themeColor)
                        Text("Transição registrada com sucesso no perímetro monitorado")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeColor.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [themeColor.opacity(0.5), themeColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .activityBackgroundTint(Color(UIColor.systemBackground))
        .activitySystemActionForegroundColor(Color.primary)
    }
}

// MARK: - View para Alertas de Emergência

@available(iOS 16.1, *)
struct EmergencyWidgetView: View {
    let state: BipeAlertActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                Image(systemName: "exclamationmark.shield.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .foregroundColor(.red)
            }
            .frame(width: 48, height: 48)
            .shadow(color: Color.red.opacity(0.4), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(state.nickname)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(state.status.uppercased())
                        .font(.caption2)
                        .fontWeight(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.red))
                        .foregroundColor(.white)
                }
                
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    
                    Text(state.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                )
        )
        .activityBackgroundTint(Color(UIColor.systemBackground))
        .activitySystemActionForegroundColor(Color.primary)
    }
}

// MARK: - View para Evento de Distância ("distance" / "APROXIMAR" / "AFASTAR") - Compact UI

@available(iOS 16.1, *)
struct DistanceWidgetView: View {
    let state: BipeAlertActivityAttributes.ContentState
    
    var isApproaching: Bool {
        let ev = state.event?.lowercased() ?? ""
        let st = state.status.lowercased()
        return ev.contains("aproxim") || st.contains("aproxim") || ev == "enter"
    }
    
    var themeColor: Color {
        isApproaching ? Color(red: 0.18, green: 0.80, blue: 0.44) : Color.orange
    }
    
    var statusTitle: String {
        isApproaching ? "SE APROXIMOU" : "SE AFASTOU"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: Header com selo de aproximar/afastar
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.18))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(themeColor.opacity(0.4), lineWidth: 1))
                    
                    Image(systemName: isApproaching ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeColor)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.nickname)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("Alerta de Distância")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(statusTitle)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(themeColor))
                .foregroundColor(.black)
            }
            
            // MARK: Linha Compacta: [Target] / [Alvo] e Distância
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    if let target = state.target, !target.isEmpty {
                        DeviceBadgeView(item: target, themeColor: themeColor)
                    }
                    
                    Text("/")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    if let alvo = state.alvo, !alvo.isEmpty {
                        DeviceBadgeView(item: alvo, themeColor: themeColor)
                    }
                }
                
                Spacer()
                
                if let dist = state.distancia, !dist.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(themeColor)
                        Text(dist)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(themeColor.opacity(0.3), lineWidth: 1.5)
                )
        )
        .activityBackgroundTint(Color(UIColor.systemBackground))
        .activitySystemActionForegroundColor(Color.primary)
    }
}

// MARK: - Live Activity Widget Principal

@available(iOS 16.1, *)
public struct BipeWidgetExtensionLiveActivity: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: BipeAlertActivityAttributes.self) { context in
            let isDistance = context.state.activityType == "distance" || context.state.target != nil || (context.state.event?.lowercased().contains("aproxim") ?? false) || (context.state.event?.lowercased().contains("afast") ?? false)
            if isDistance {
                DistanceWidgetView(state: context.state)
            } else if context.state.activityType == "transition" || context.state.way != nil {
                TransitionWidgetView(state: context.state)
            } else {
                EmergencyWidgetView(state: context.state)
            }
        } dynamicIsland: { context in
            let isDistance = context.state.activityType == "distance" || context.state.target != nil || (context.state.event?.lowercased().contains("aproxim") ?? false) || (context.state.event?.lowercased().contains("afast") ?? false)
            let isTransition = context.state.activityType == "transition" || context.state.way != nil
            let isExit = (context.state.event?.lowercased() ?? "").contains("exit") || (context.state.event?.lowercased() ?? "").contains("saida")
            let isApproaching = (context.state.event?.lowercased() ?? "").contains("aproxim") || context.state.status.lowercased().contains("aproxim")
            
            let themeColor: Color = isDistance ? (isApproaching ? Color(red: 0.18, green: 0.80, blue: 0.44) : .orange) : (isTransition ? (isExit ? .orange : Color(red: 0.18, green: 0.80, blue: 0.44)) : .red)
            let regionName = context.state.way ?? context.state.address
            let devicesList = context.state.devices ?? []
            
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        if isDistance {
                            HStack(spacing: 4) {
                                if let target = context.state.target {
                                    DeviceBadgeView(item: target, themeColor: themeColor)
                                }
                                Text("/")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                if let alvo = context.state.alvo {
                                    DeviceBadgeView(item: alvo, themeColor: themeColor)
                                }
                            }
                        } else if isTransition {
                            if let triggerIcon = context.state.icon ?? context.state.iconUrl, !triggerIcon.isEmpty {
                                DeviceBadgeView(item: triggerIcon, themeColor: themeColor)
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(themeColor.opacity(0.25))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(themeColor)
                                }
                            }
                            if !regionName.lowercased().contains("monitora") {
                                Text(regionName)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            } else {
                                Text(context.state.nickname)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        } else {
                            Image(systemName: "exclamationmark.shield.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.red)
                            Text(context.state.nickname)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if isDistance {
                        Text(isApproaching ? "APROXIMOU" : "AFASTOU")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(themeColor))
                            .foregroundColor(.black)
                    } else if isTransition {
                        HStack(spacing: 4) {
                            Image(systemName: isExit ? "arrow.left.to.line.compact" : "arrow.right.to.line.compact")
                                .font(.system(size: 10, weight: .bold))
                            Text(isExit ? "SAIU" : "ENTROU")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(themeColor))
                        .foregroundColor(.black)
                    } else {
                        Text(context.state.status.uppercased())
                            .font(.caption2)
                            .fontWeight(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red))
                            .foregroundColor(.white)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if isDistance {
                        if let dist = context.state.distancia {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.footnote)
                                    .foregroundColor(themeColor)
                                Text("Distância: \(dist)")
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 4)
                        }
                    } else if isTransition {
                        if !devicesList.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(devicesList.prefix(3), id: \.self) { dev in
                                    DeviceBadgeView(item: dev, themeColor: themeColor)
                                }
                                
                                if devicesList.count > 3 {
                                    Text("+\(devicesList.count - 3)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(themeColor)
                                }
                            }
                            .padding(.top, 4)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.footnote)
                                    .foregroundColor(themeColor)
                                Text(regionName)
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        HStack(alignment: .center, spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                            
                            Text(context.state.address)
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(2)
                        }
                        .padding(.top, 4)
                    }
                }
            } compactLeading: {
                if isDistance {
                    Image(systemName: isApproaching ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .foregroundColor(themeColor)
                } else if isTransition {
                    Image(systemName: isExit ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                        .foregroundColor(themeColor)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            } compactTrailing: {
                if isDistance {
                    if let dist = context.state.distancia {
                        Text(dist)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(themeColor)
                    } else {
                        Text(isApproaching ? "APROX" : "AFAST")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(themeColor)
                    }
                } else if isTransition {
                    if let firstDev = devicesList.first {
                        DeviceBadgeView(item: firstDev, themeColor: themeColor)
                    } else if !regionName.lowercased().contains("monitora") {
                        Text(regionName)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(themeColor)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeColor)
                    }
                } else {
                    Text(context.state.nickname)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            } minimal: {
                if isDistance {
                    Image(systemName: isApproaching ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .foregroundColor(themeColor)
                } else if isTransition {
                    if let firstDev = devicesList.first {
                        DeviceBadgeView(item: firstDev, themeColor: themeColor)
                    } else {
                        Image(systemName: isExit ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                            .foregroundColor(themeColor)
                    }
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }
            .keylineTint(themeColor)
        }
    }
}

