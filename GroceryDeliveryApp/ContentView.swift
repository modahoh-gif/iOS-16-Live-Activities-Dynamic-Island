//
//  ContentView.swift
//  GroceryDeliveryApp
//
//  Created by Batikan Sosun on 13.08.2022.
//

import SwiftUI
import ActivityKit

@available(iOS 16.1, *)
struct ContentView: View {
    @State var activities = Activity<GroceryDeliveryAppAttributes>.activities
    @State private var webSocket: URLSessionWebSocketTask?
    @State private var currentPriceText: String = "Connecting..."

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Bitcoin Live Dynamic Island")
                        .font(.headline)
                    
                    Text(currentPriceText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.green)
                    
                    Button(action: {
                        createActivity()
                        listAllDeliveries()
                    }) {
                        Text("Start Bitcoin Live Activity").font(.headline)
                    }.tint(.orange)
                    
                    Button(action: {
                        endAllActivity()
                        listAllDeliveries()
                    }) {
                        Text("End All Activities").font(.headline)
                    }.tint(.red)
                }
                Section {
                    if !activities.isEmpty {
                        Text("Active Trackers")
                    }
                    activitiesView()
                }
            }
            .navigationTitle("Bitcoin Tracker")
            .fontWeight(.ultraLight)
        }
        .onAppear {
            startWebSocketStream()
        }
    }
    
    func startWebSocketStream() {
        let url = URL(string: "wss://stream.binance.com:9443/ws/btcusdt@ticker")!
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        receiveWebSocketMessage()
    }
    
    func receiveWebSocketMessage() {
        webSocket?.receive { result in
            switch result {
            case .success(let message):
                if case .string(let text) = message,
                   let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let priceStr = json["c"] as? String {
                    let doublePrice = Double(priceStr) ?? 0
                    let formattedPrice = String(format: "$%.1f", doublePrice)
                    
                    DispatchQueue.main.async {
                        self.currentPriceText = formattedPrice
                        // تحديث تلقائي فوري لكل الأنشطة الحية المفتوحة بالجزيرة
                        updateAllActiveLiveActivities(with: formattedPrice)
                    }
                }
                receiveWebSocketMessage()
            case .failure:
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    startWebSocketStream()
                }
            }
        }
    }
    
    func updateAllActiveLiveActivities(with price: String) {
        Task {
            for activity in Activity<GroceryDeliveryAppAttributes>.activities {
                let updatedStatus = GroceryDeliveryAppAttributes.LiveDeliveryData(courierName: price, deliveryTime: .now + 3600)
                await activity.update(using: updatedStatus)
            }
        }
    }
    
    func createActivity() {
        let attributes = GroceryDeliveryAppAttributes(numberOfGroceyItems: 1)
        let contentState = GroceryDeliveryAppAttributes.LiveDeliveryData(courierName: currentPriceText, deliveryTime: .now + 3600)
        do {
            let _ = try Activity<GroceryDeliveryAppAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: .token)
        } catch (let error) {
            print(error.localizedDescription)
        }
    }
    
    func endAllActivity() {
        Task {
            for activity in Activity<GroceryDeliveryAppAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
    
    func listAllDeliveries() {
        var activities = Activity<GroceryDeliveryAppAttributes>.activities
        activities.sort { $0.id > $1.id }
        self.activities = activities
    }
}

@available(iOS 16.1, *)
extension ContentView {
    func activitiesView() -> some View {
        var body: some View {
            ScrollView {
                ForEach(activities, id: \.id) { activity in
                    let priceValue = activity.contentState.courierName
                    HStack(alignment: .center) {
                        Text("BTC: \(priceValue)")
                        Spacer()
                        Text("End")
                            .font(.headline)
                            .foregroundColor(.red)
                            .onTapGesture {
                                Task {
                                    await activity.end(dismissalPolicy: .immediate)
                                    listAllDeliveries()
                                }
                            }
                    }
                }
            }
        }
        return body
    }
}
