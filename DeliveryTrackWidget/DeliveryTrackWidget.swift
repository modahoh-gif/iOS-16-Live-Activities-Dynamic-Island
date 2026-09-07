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
                    HStack {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundColor(.orange)
                        Text(context.attributes.currencyPair)
                            .font(.headline)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.price)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.green)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Binance Realtime Stream")
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
                Text(context.state.price)
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
        HStack {
            Image(systemName: "bitcoinsign.circle.fill")
                .foregroundColor(.orange)
                .font(.largeTitle)
            
            VStack(alignment: .leading) {
                Text(context.attributes.currencyPair)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("Bitcoin Price")
                    .font(.headline)
            }
            Spacer()
            Text(context.state.price)
                .font(.title)
                .bold()
                .foregroundColor(.green)
        }
        .padding()
    }
}
