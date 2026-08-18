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
@main
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

@available(iOS 16.1, *)
public struct BipeLiveActivityWidget: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: BipeAlertActivityAttributes.self) { context in
            // Lock Screen / Notification Center View
            HStack(spacing: 14) {
                BipeIconView(iconLocalPath: context.state.iconLocalPath)
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.red.opacity(0.4), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(context.state.nickname)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(context.state.status.uppercased())
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
                        
                        Text(context.state.address)
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
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        BipeIconView(iconLocalPath: context.state.iconLocalPath)
                            .frame(width: 28, height: 28)
                        
                        Text(context.state.nickname)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.status.uppercased())
                        .font(.caption2)
                        .fontWeight(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.red))
                        .foregroundColor(.white)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
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
            } compactLeading: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            } compactTrailing: {
                Text(context.state.nickname)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
            .keylineTint(Color.red)
        }
    }
}
#endif
