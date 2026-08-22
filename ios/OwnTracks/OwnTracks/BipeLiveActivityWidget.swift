//
//  BipeLiveActivityWidget.swift
//  OwnTracks
//

import Foundation

#if canImport(WidgetKit) && canImport(ActivityKit) && canImport(SwiftUI)
import WidgetKit
import ActivityKit
import SwiftUI
import AppIntents

@available(iOS 17.0, *)
struct ConfirmBipeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Confirmar Bipe"
    
    @Parameter(title: "Execução ID")
    var execucaoId: String?
    
    init() {}
    init(execucaoId: String?) {
        self.execucaoId = execucaoId
    }
    
    func perform() async throws -> some IntentResult {
        BipeLiveActivityManager.sendBipeConfirmation(execucaoId: execucaoId)
        return .result()
    }
}

@available(iOS 16.1, *)
struct BipeWidgetBundle: WidgetBundle {
    var body: some Widget {
        BipeLiveActivityWidget()
    }
}

// MARK: - View para Transições de Região ("transition") - Premium UI

@available(iOS 16.1, *)
struct TransitionWidgetView: View {
    let state: BipeAlertActivityAttributes.ContentState
    
    var isExit: Bool {
        let ev = state.event?.lowercased() ?? ""
        let st = state.status.lowercased()
        return ev.contains("exit") || ev.contains("leave") || ev.contains("left") || ev.contains("saida") || ev.contains("saída") || ev.contains("saiu") || ev.contains("out") ||
               st.contains("exit") || st.contains("leave") || st.contains("left") || st.contains("saida") || st.contains("saída") || st.contains("saiu") || st.contains("out")
    }
    
    var themeColor: Color {
        isExit ? Color.orange : Color(red: 0.18, green: 0.80, blue: 0.44) // Emerald Green vs Amber Orange
    }
    
    var eventTitle: String {
        isExit ? "SAIU DA REGIÃO" : "ENTROU NA REGIÃO"
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
                    
                    let triggerIcon = (state.icon != nil && !state.icon!.isEmpty) ? state.icon! : ((state.iconUrl != nil && !state.iconUrl!.isEmpty) ? state.iconUrl! : "abacaxi")
                    DeviceBadgeView(item: triggerIcon, themeColor: themeColor, size: 32)
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
                    
                    Text("ZONA DE MONITORAMENTO")
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
                        Image(systemName: "shield.checkerboard")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeColor)
                        
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
                        ForEach(devicesList.prefix(8), id: \.self) { devName in
                            HStack(spacing: 6) {
                                // Avatar circular do dispositivo
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
                                    
                                    Image(systemName: devName.lowercased().contains("car") ? "car.fill" : "iphone")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                Text(devName)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .padding(.leading, 4)
                            .padding(.trailing, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        
                        if devicesList.count > 8 {
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                Text("+\(devicesList.count - 8)")
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

private class WidgetBundleClass {}

@available(iOS 16.1, *)
struct DeviceBadgeView: View {
    let item: String
    let themeColor: Color
    var size: CGFloat = 20.0
    
    var cleanName: String {
        let name = item.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasSuffix(".png") || name.hasSuffix(".svg") || name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") {
            return (name as NSString).deletingPathExtension
        }
        return name
    }
    
    var uiImage: UIImage? {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        if let img = UIImage(named: cleanName) ?? UIImage(named: item) ?? UIImage(named: "drawable/\(cleanName)") ?? UIImage(named: "drawable/\(item)") {
            return img
        }
        
        let ext = (item as NSString).pathExtension
        guard !ext.isEmpty else { return nil }
        
        let possibleTypes = Array(Set([ext, "png", "PNG", "jpg", "JPG", "jpeg"])).filter { !$0.isEmpty }
        let bundles = [Bundle.main, Bundle(for: WidgetBundleClass.self)]
        
        for bundle in bundles {
            for type in possibleTypes {
                if let path = bundle.path(forResource: cleanName, ofType: type), let img = UIImage(contentsOfFile: path) {
                    return img
                }
                if let path = bundle.path(forResource: item, ofType: type), let img = UIImage(contentsOfFile: path) {
                    return img
                }
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
        if n.contains("car") || n.contains("carro") || n.contains("auto") { return "car.fill" }
        if n.contains("person") || n.contains("user") || n.contains("pessoa") || n.contains("abacaxi") { return "person.fill" }
        if n.contains("iphone") || n.contains("phone") || n.contains("mobile") || n.contains("celular") { return "iphone" }
        if n.contains("bus") || n.contains("onibus") { return "bus.fill" }
        if n.contains("bicycle") || n.contains("bike") || n.contains("bicicleta") { return "bicycle" }
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
                    .frame(width: size, height: size)
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
                        .frame(width: size, height: size)
                    
                    Image(systemName: systemIcon)
                        .font(.system(size: size * 0.48, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(2)
    }
}

// MARK: - View para Alertas de Emergência

@available(iOS 16.1, *)
struct EmergencyWidgetView: View {
    let state: BipeAlertActivityAttributes.ContentState

    var receivedIcon: String? {
        if let icon = state.icon, !icon.isEmpty { return icon }
        if let iconUrl = state.iconUrl, !iconUrl.isEmpty { return iconUrl }
        if let target = state.target, !target.isEmpty { return target }
        if let firstDev = state.devices?.first, !firstDev.isEmpty { return firstDev }
        return nil
    }

    var badgeText: String {
        let st = state.status.lowercased()
        if st == "start" || st == "emergency" || st == "emergencia" || st == "emergência" || st.isEmpty {
            return "EMERGÊNCIA"
        }
        return state.status.uppercased()
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                        Image(systemName: "exclamationmark.shield.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                            .foregroundColor(.red)
                    }
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.red.opacity(0.4), radius: 4, x: 0, y: 2)
                    
                    if let iconItem = receivedIcon {
                        DeviceBadgeView(item: iconItem, themeColor: .red, size: 44)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(state.nickname)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(badgeText)
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
            
            let act = state.activityType?.lowercased() ?? ""
            let st = state.status.lowercased()
            let ev = state.event?.lowercased() ?? ""
            let isBipeAlert = act.contains("bipe") || st.contains("bipe") || ev.contains("bipe")
            if isBipeAlert {
                if #available(iOS 17.0, *) {
                    Button(intent: ConfirmBipeIntent(execucaoId: state.execucaoId)) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text("CONFIRMAR BIPE")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [Color.green, Color(red: 0.15, green: 0.70, blue: 0.35)], startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                } else {
                    Link(destination: URL(string: "bipe://confirm?execucaoId=\(state.execucaoId ?? "")")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text("CONFIRMAR BIPE")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [Color.green, Color(red: 0.15, green: 0.70, blue: 0.35)], startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.top, 4)
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

// MARK: - View para Evento de Rotina ("routine") - Compact UI

@available(iOS 16.1, *)
struct RoutineWidgetView: View {
    let state: BipeAlertActivityAttributes.ContentState
    
    var themeColor: Color {
        Color(red: 0.55, green: 0.27, blue: 0.80)
    }
    
    var deviceIcon: String {
        if let icon = state.icon, !icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return icon
        }
        if let iconUrl = state.iconUrl, !iconUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return iconUrl
        }
        return "abacaxi"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(themeColor.opacity(0.4), lineWidth: 1.5)
                        )
                    
                    DeviceBadgeView(item: deviceIcon, themeColor: themeColor, size: 34)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.nickname)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(state.address)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("ROTINA")
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
            
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(themeColor)
                Text(state.address)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(themeColor.opacity(0.08))
            )
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
public struct BipeLiveActivityWidget: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: BipeAlertActivityAttributes.self) { context in
            let st = context.state.status.lowercased()
            let act = context.state.activityType?.lowercased() ?? ""
            let ev = context.state.event?.lowercased() ?? ""
            
            let isBipe = act.contains("bipe") || st.contains("bipe") || ev.contains("bipe") || context.state.execucaoId != nil || st == "start"
            let isEmergency = isBipe || act.contains("emergency") || st.contains("emergency") || st.contains("emergencia") || st.contains("emergência")
            let isRoutine = !isEmergency && (act.contains("routine") || act.contains("rotina") || st.contains("routine") || st.contains("rotina") || ev.contains("routine") || ev.contains("rotina"))
            let hasValidTarget = (context.state.target != nil && !(context.state.target?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
            let isDistance = !isEmergency && !isRoutine && (act.contains("distance") || st.contains("distance") || hasValidTarget || ev.contains("aproxim") || ev.contains("afast"))
            let isTransition = !isEmergency && !isDistance && !isRoutine && (act.contains("transition") || st.contains("transition") || (ev.contains("enter") || ev.contains("exit") || ev.contains("leave") || ev.contains("saida")))
            let isActive = ev.contains("active") || ev.contains("active")

            if isEmergency {
                EmergencyWidgetView(state: context.state)
            } else if isRoutine {
                RoutineWidgetView(state: context.state)
            } else if isTransition {
                TransitionWidgetView(state: context.state)
            } else {
                EmergencyWidgetView(state: context.state)
            }
        } dynamicIsland: { context in
            let st = context.state.status.lowercased()
            let act = context.state.activityType?.lowercased() ?? ""
            let ev = context.state.event?.lowercased() ?? ""
            
            let isBipe = act.contains("bipe") || st.contains("bipe") || ev.contains("bipe") || context.state.execucaoId != nil || st == "start"
            let isEmergency = isBipe || act.contains("emergency") || st.contains("emergency") || st.contains("emergencia") || st.contains("emergência")
            let isRoutine = !isEmergency && (act.contains("routine") || act.contains("rotina") || st.contains("routine") || st.contains("rotina") || ev.contains("routine") || ev.contains("rotina"))
            let hasValidTarget = (context.state.target != nil && !(context.state.target?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
            let isDistance = !isEmergency && !isRoutine && (act.contains("distance") || st.contains("distance") || hasValidTarget || ev.contains("aproxim") || ev.contains("afast"))
            let isTransition = !isEmergency && !isDistance && !isRoutine && (act.contains("transition") || st.contains("transition") || (ev.contains("enter") || ev.contains("exit") || ev.contains("leave") || ev.contains("saida")))
            
            let isExit = ev.contains("exit") || ev.contains("leave") || ev.contains("left") || ev.contains("saida") || ev.contains("saída") || ev.contains("saiu") || ev.contains("out") ||
                         st.contains("exit") || st.contains("leave") || st.contains("left") || st.contains("saida") || st.contains("saída") || st.contains("saiu") || st.contains("out")
            let routineThemeColor = Color(red: 0.55, green: 0.27, blue: 0.80)
            let themeColor: Color = isRoutine ? routineThemeColor : (isEmergency ? .red : (isDistance ? Color(red: 0.18, green: 0.80, blue: 0.44) : (isTransition ? (isExit ? .orange : Color(red: 0.18, green: 0.80, blue: 0.44)) : .red)))
            let regionName = context.state.way ?? context.state.address
            let devicesList = context.state.devices ?? []
            let isActive = ev.contains("active") || ev.contains("active")
            
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        if isRoutine {
                            let routineIcon = (context.state.icon != nil && !context.state.icon!.isEmpty) ? context.state.icon! : ((context.state.iconUrl != nil && !context.state.iconUrl!.isEmpty) ? context.state.iconUrl! : "abacaxi")
                            DeviceBadgeView(item: routineIcon, themeColor: themeColor, size: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(context.state.nickname)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(context.state.address)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        } else if isTransition {
                            let triggerIcon = (context.state.icon != nil && !context.state.icon!.isEmpty) ? context.state.icon! : ((context.state.iconUrl != nil && !context.state.iconUrl!.isEmpty) ? context.state.iconUrl! : "abacaxi")
                            DeviceBadgeView(item: triggerIcon, themeColor: themeColor, size: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(regionName)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text("Zona Monitorada")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
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
                    if isRoutine {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("ROTINA")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(themeColor))
                        .foregroundColor(.white)
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
                    } else if isActive {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10, weight: .bold))
                            Text("ATIVO")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(themeColor))
                        .foregroundColor(.black)
                    } else {
                        let st = context.state.status.lowercased()
                        let emergencyStatusText = (st == "start" || st == "emergency" || st == "emergencia" || st == "emergência" || st.isEmpty) ? "EMERGÊNCIA" : context.state.status.uppercased()
                        Text(emergencyStatusText)
                            .font(.caption2)
                            .fontWeight(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red))
                            .foregroundColor(.white)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if isRoutine {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.footnote)
                                .foregroundColor(themeColor)
                            Text("Rotina não atendida")
                                .font(.footnote)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 4)
                    } else if isTransition {
                        if !devicesList.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.checkerboard")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeColor)
                                
                                ForEach(devicesList.prefix(8), id: \.self) { dev in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(themeColor)
                                            .frame(width: 5, height: 5)
                                        Text(dev)
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.white.opacity(0.12)))
                                }
                                
                                if devicesList.count > 8 {
                                    Text("+\(devicesList.count - 8)")
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
                if isRoutine {
                    let routineIcon = (context.state.icon != nil && !context.state.icon!.isEmpty) ? context.state.icon! : ((context.state.iconUrl != nil && !context.state.iconUrl!.isEmpty) ? context.state.iconUrl! : "abacaxi")
                    DeviceBadgeView(item: routineIcon, themeColor: themeColor)
                } else if isTransition {
                    Image(systemName: isExit ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                        .foregroundColor(themeColor)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            } compactTrailing: {
                if isRoutine {
                    Text("ROTINA")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(themeColor)
                } else if isTransition {
                    Text(regionName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(themeColor)
                        .lineLimit(1)
                } else {
                    Text(context.state.nickname)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            } minimal: {
                if isRoutine {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundColor(themeColor)
                } else if isTransition {
                    Image(systemName: isExit ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                        .foregroundColor(themeColor)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }
            .keylineTint(themeColor)
        }
    }
}
#endif