//
//  ContentView.swift
//  GroceryDeliveryApp
//
//  Created by Batikan Sosun on 13.08.2022.
//

import SwiftUI
import ActivityKit
import AVFoundation

@available(iOS 16.1, *)
struct ContentView: View {
    @State var activities = Activity<GroceryDeliveryAppAttributes>.activities
    @State private var currentPriceText: String = "$..."
    @State private var isRunning: Bool = false
    @Environment(\.scenePhase) private var scenePhase

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
                        stopLoop()
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
            setupAudioSession()
            startLoop()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // إعادة تنشيط الجلب فوراً عندما يعود المستخدم للتطبيق
                startLoop()
            }
        }
    }
    
    // تشغيل جلسة صوتية صامتة لإبقاء التطبيق نشطاً أطول فترة ممكنة بالخلفية
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    func startLoop() {
        guard !isRunning else { return }
        isRunning = true
        
        Task {
            while isRunning {
                await fetchPrice()
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // كل ثانيتين
                } catch {
                    break
                }
            }
        }
    }
    
    func stopLoop() {
        isRunning = false
    }
    
    func fetchPrice() async {
        guard let url = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT") else { return }
        
        // إعداد طلب مع وقت انتظار قصير جداً لمنع تعليق خيط المعالجة
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let priceStr = json["price"] as? String {
                let doublePrice = Double(priceStr) ?? 0
                let formattedPrice = String(format: "$%.1f", doublePrice)
                
                await MainActor.run {
                    self.currentPriceText = formattedPrice // تم تصحيح الخطأ هنا
                    updateAllActiveLiveActivities(with: formattedPrice)
                }
            }
        } catch {
            // في حال فشل الشبكة المؤقت, نحاول مجدداً في الدورة القادمة
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
    @ViewBuilder
    func activitiesView() -> some View { // تم إضافة كلمة func و @ViewBuilder لتصحيح الدالة
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
}
