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
    @State private var currentPriceText: String = "Loading..."
    @State private var isRunning: Bool = false

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
                        startBackgroundLoop()
                        listAllDeliveries()
                    }) {
                        Text("Start Bitcoin Live Activity").font(.headline)
                    }.tint(.orange)
                    
                    Button(action: {
                        isRunning = false
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
            isRunning = true
            startBackgroundLoop()
        }
        .onDisappear {
            // لا نوقف الحلقة هنا لكي تستمر بتحديث النشاط الحي بالخلفية قدر الإمكان
        }
    }
    
    // حلقة مهام غير同期 (Async Task Loop) مقاومة للتجميد السريع
    func startBackgroundLoop() {
        guard !isRunning else { return }
        isRunning = true
        
        Task {
            while isRunning {
                await fetchBitcoinPriceAsync()
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // كل ثانيتين
                } catch {
                    break
                }
            }
        }
    }
    
    func fetchBitcoinPriceAsync() async {
        guard let url = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let priceStr = json["price"] as? String {
                let doublePrice = Double(priceStr) ?? 0
                let formattedPrice = String(format: "$%.1f", doublePrice)
                
                await MainActor.run {
                    self.currentPriceText = formattedPrice
                    updateAllActiveLiveActivities(with: formattedPrice)
                }
            }
        } catch {
            // تجاهل أخطاء الشبكة المؤقتة وإعادة المحاولة في الدورة القادمة
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
        isRunning = false
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
