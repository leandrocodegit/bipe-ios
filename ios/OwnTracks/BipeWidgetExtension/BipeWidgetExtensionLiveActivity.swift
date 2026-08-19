//
//  BipeWidgetExtensionLiveActivity.swift
//  BipeWidgetExtension
//
//  Created by user291221 on 8/18/26.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BipeWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct BipeWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BipeWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension BipeWidgetExtensionAttributes {
    fileprivate static var preview: BipeWidgetExtensionAttributes {
        BipeWidgetExtensionAttributes(name: "World")
    }
}

extension BipeWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: BipeWidgetExtensionAttributes.ContentState {
        BipeWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: BipeWidgetExtensionAttributes.ContentState {
         BipeWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: BipeWidgetExtensionAttributes.preview) {
   BipeWidgetExtensionLiveActivity()
} contentStates: {
    BipeWidgetExtensionAttributes.ContentState.smiley
    BipeWidgetExtensionAttributes.ContentState.starEyes
}
