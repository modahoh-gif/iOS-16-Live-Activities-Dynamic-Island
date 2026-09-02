//
//  DeliveryTrackWidget.swift
//  DeliveryTrackWidget
//
//  Created by Batikan Sosun on 13.08.2022.
//

import ActivityKit
import WidgetKit
import SwiftUI

@main
struct Widgets: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            GroceryDeliveryApp()
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct GroceryDeliveryApp: Widget {
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GroceryDeliveryAppAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("BTC/USDT")
                        .font(.headline)
                        .foregroundColor(.orange)
                 }
                 
                 DynamicIslandExpandedRegion(.trailing) {
                     Text(context.state.courierName)
                         .font(.headline)
                         .foregroundColor(.green)
                 }
                 
                 DynamicIslandExpandedRegion(.center) {
                     Text("Live Market Price")
                         .font(.caption2)
                         .foregroundColor(.gray)
                 }
                 
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Zero Latency Tracker")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
              } compactLeading: {
                  HStack(spacing: 2) {
                      Image(systemName: "bitcoinsign.circle.fill")
                          .foregroundColor(.orange)
                      Text("BTC")
                          .font(.caption2)
                          .bold()
                  }
              } compactTrailing: {
                  Text(context.state.courierName)
                      .font(.caption2)
                      .bold()
                      .foregroundColor(.green)
              } minimal: {
                  Image(systemName: "bitcoinsign.circle.fill")
                      .foregroundColor(.orange)
              }
              .keylineTint(.orange)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct LockScreenView: View {
    var context: ActivityViewContext<GroceryDeliveryAppAttributes>
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title)
                VStack(alignment: .leading) {
                    Text("Bitcoin Live Price")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(context.state.courierName)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.green)
                }
            }
        }.padding(10)
    }
}
