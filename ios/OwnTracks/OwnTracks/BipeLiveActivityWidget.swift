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

// MARK: - View para Transições de Região ("transition")

@available(iOS 16.1, *)
struct TransitionWidgetView: View {
    let state: BipeAlertActivityAttributes.ContentState
    
    var isExit: Bool {
        let ev = state.event?.lowercased() ?? ""
        return ev.contains("exit") || ev.contains("saida") || ev.contains("saída")
    }
    
    var themeColor: Color {
        isExit ? Color.orange : Color.green
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
        VStack(alignment: .leading, spacing: 10) {
            // Cabeçalho: Ícone da Região + Nome da Região + Badge (ENTROU / SAIU)
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.18))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(themeColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(regionName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("Região Monitorada")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: eventIcon)
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text(eventTitle)
                        .font(.caption2)
                        .fontWeight(.black)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(themeColor.opacity(0.2)))
                .overlay(Capsule().stroke(themeColor.opacity(0.4), lineWidth: 1))
                .foregroundColor(themeColor)
            }
            
            // Seção de Dispositivos presentes na região
            if !devicesList.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkerboard")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("DISPOSITIVOS NA ÁREA (\(devicesList.count))")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        ForEach(devicesList.prefix(4), id: \.self) { devName in
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 10))
                                Text(devName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        }
                        
                        if devicesList.count > 4 {
                            Text("+\(devicesList.count - 4)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(themeColor.opacity(0.15)))
                                .foregroundColor(themeColor)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(themeColor.opacity(0.35), lineWidth: 1.5)
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
            let themeColor: Color = isTransition ? (isExit ? .orange : .green) : .red
            let regionName = context.state.way ?? context.state.address
            let devicesList = context.state.devices ?? []
            
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        if isTransition {
                            ZStack {
                                Circle().fill(themeColor.opacity(0.2)).frame(width: 28, height: 28)
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(themeColor)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(regionName)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text("Região")
                                    .font(.caption2)
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
                        Text(isExit ? "SAIU" : "ENTROU")
                            .font(.caption2)
                            .fontWeight(.black)
                            .padding(.horizontal, 8)
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
                            HStack(spacing: 6) {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .font(.caption2)
                                    .foregroundColor(themeColor)
                                
                                Text(devicesList.joined(separator: ", "))
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
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
                    Image(systemName: isExit ? "figure.walk.departure" : "figure.walk.arrival")
                        .foregroundColor(themeColor)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            } compactTrailing: {
                if isTransition {
                    Text(regionName)
                        .font(.caption2)
                        .fontWeight(.bold)
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
                    Image(systemName: isExit ? "mappin.slash.fill" : "mappin.circle.fill")
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
