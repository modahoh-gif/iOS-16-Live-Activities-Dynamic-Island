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
    @State private var webSocket: URLSessionWebSocketTask?
    @State private var currentPriceText: String = "Connecting..."
    @State private var audioPlayer: AVAudioPlayer?

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
            setupSilentAudio()
            startWebSocketStream()
        }
    }
    
    // تشغيل صوت صامت بالخلفية لمنع نظام iOS من إيقاف التطبيق والاتصال
    func setupSilentAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // إنشاء ملف صوتي صامت قصير جداً وتكراره بلا حدود
            let bundle = Bundle.main
            if let soundURL = bundle.url(forResource: "silent", withExtension: "wav") ?? createEmptyWavFile() {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.volume = 0.01
                audioPlayer?.play()
            }
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    func createEmptyWavFile() -> URL? {
        let mutableData = NSMutableData()
        let sampleRate: Int32 = 8000
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = sampleRate * Int32(numChannels) * Int32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize: Int32 = sampleRate * 2 // ثانيتين صوت صامت
        let chunkSize = 36 + dataSize
        
        mutableData.append(Data("RIFF".utf8))
        mutableData.append(withUnsafeBytes(of: chunkSize.littleEndian) { Data($0) })
        mutableData.append(Data("WAVE".utf8))
        mutableData.append(Data("fmt ".utf8))
        mutableData.append(withUnsafeBytes(of: Int32(16).littleEndian) { Data($0) })
        mutableData.append(withUnsafeBytes(of: Int16(1).littleEndian) { Data($0) })
        mutableData.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        mutableData.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        mutableData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        mutableData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        mutableData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        mutableData.append(Data("data".utf8))
        mutableData.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        
        let zeros = Data(repeating: 0, count: Int(dataSize))
        mutableData.append(zeros)
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("silent.wav")
        try? mutableData.write(to: tempDir)
        return tempDir
    }
    
    func startWebSocketStream() {
        webSocket?.cancel()
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
                        updateAllActiveLiveActivities(with: formattedPrice)
                    }
                }
                // متابعة الاستماع للرسائل التالية
                receiveWebSocketMessage()
            case .failure:
                // إعادة الاتصال الفوري تلقائياً في حال حدوث أي انقطاع
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
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
