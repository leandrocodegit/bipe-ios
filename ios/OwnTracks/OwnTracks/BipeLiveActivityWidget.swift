//
//  BipeLiveActivityWidget.swift
//  OwnTracks
//

import Foundation

#if canImport(WidgetKit) && canImport(ActivityKit) && canImport(SwiftUI)
import WidgetKit
import ActivityKit
import SwiftUI

@available(iOS 16.1, *)
struct BipeWidgetBundle: WidgetBundle {
    var body: some Widget {
        BipeLiveActivityWidget()
    }
}

@available(iOS 16.1, *)
struct BipeIconView: View {
    let iconLocalPath: String?
    
    var body: some View {
        if let path = iconLocalPath,
           let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
        } else {
            Image(systemName: "exclamationmark.shield.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.red)
        }
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
                    
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(themeColor)
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
                        ForEach(devicesList.prefix(3), id: \.self) { devName in
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
                        
                        if devicesList.count > 3 {
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                Text("+\(devicesList.count - 3)")
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
            BipeIconView(iconLocalPath: state.iconLocalPath)
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

// MARK: - Live Activity Widget Principal

@available(iOS 16.1, *)
public struct BipeLiveActivityWidget: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: BipeAlertActivityAttributes.self) { context in
            if context.state.activityType == "transition" || context.state.way != nil {
                TransitionWidgetView(state: context.state)
            } else {
                EmergencyWidgetView(state: context.state)
            }
        } dynamicIsland: { context in
            let isTransition = context.state.activityType == "transition" || context.state.way != nil
            let isExit = (context.state.event?.lowercased() ?? "").contains("exit") || (context.state.event?.lowercased() ?? "").contains("saida")
            let themeColor: Color = isTransition ? (isExit ? .orange : Color(red: 0.18, green: 0.80, blue: 0.44)) : .red
            let regionName = context.state.way ?? context.state.address
            let devicesList = context.state.devices ?? []
            
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        if isTransition {
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.25))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(themeColor)
                            }
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
                            BipeIconView(iconLocalPath: context.state.iconLocalPath)
                                .frame(width: 28, height: 28)
                            Text(context.state.nickname)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if isTransition {
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
                    if isTransition {
                        if !devicesList.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.checkerboard")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeColor)
                                
                                ForEach(devicesList.prefix(3), id: \.self) { dev in
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
                if isTransition {
                    Image(systemName: isExit ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                        .foregroundColor(themeColor)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            } compactTrailing: {
                if isTransition {
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
                if isTransition {
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
