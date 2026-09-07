import SwiftUI
import ActivityKit
import AVFoundation

class BitcoinTrackerManager: ObservableObject {
    @Published var isTracking = false
    private var currentActivity: Activity<GroceryDeliveryAppAttributes>?
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioPlayer: AVAudioPlayer?

    func startTracking() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        setupSilentAudio()
        
        let attributes = GroceryDeliveryAppAttributes(currencyPair: "BTC/USDT")
        let initialState = GroceryDeliveryAppAttributes.ContentState(price: "Connecting...")
        
        do {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: initialState, staleDate: nil)
                currentActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } else {
                currentActivity = try Activity.request(attributes: attributes, contentState: initialState, pushType: nil)
            }
            
            isTracking = true
            connectWebSocket()
        } catch {
            print("Activity Error: \(error.localizedDescription)")
        }
    }

    func stopTracking() {
        Task {
            let finalState = GroceryDeliveryAppAttributes.ContentState(price: "Stopped")
            if #available(iOS 16.2, *) {
                await currentActivity?.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            } else {
                await currentActivity?.end(using: finalState, dismissalPolicy: .immediate)
            }
            
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            audioPlayer?.stop()
            DispatchQueue.main.async {
                self.isTracking = false
            }
        }
    }

    private func connectWebSocket() {
        let url = URL(string: "wss://stream.binance.com:9443/ws/btcusdt@ticker")!
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveData()
    }

    private func receiveData() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self, self.isTracking else { return }
            
            switch result {
            case .success(let message):
                if case .string(let text) = message, let data = text.data(using: .utf8) {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let priceStr = json["c"] as? String,
                       let priceDouble = Double(priceStr) {
                        
                        let formattedPrice = String(format: "$%.2f", priceDouble)
                        self.updateActivity(with: formattedPrice)
                    }
                }
                self.receiveData()
            case .failure:
                // إعادة الاتصال تلقائياً عند أي انقطاع
                DispatchQueue.main.async.after(deadline: .now() + 3) {
                    if self.isTracking { self.connectWebSocket() }
                }
            }
        }
    }

    private func updateActivity(with price: String) {
        Task {
            let updatedState = GroceryDeliveryAppAttributes.ContentState(price: price)
            if #available(iOS 16.2, *) {
                await currentActivity?.update(ActivityContent(state: updatedState, staleDate: nil))
            } else {
                await currentActivity?.update(using: updatedState)
            }
        }
    }

    private func setupSilentAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // ملف صوتي صامت بترميز ناعم لضمان بقاء النظام نشطاً بالخلفية
            if let silentURL = Bundle.main.url(forResource: "silent", withExtension: "mp3") {
                audioPlayer = try AVAudioPlayer(contentsOf: silentURL)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.play()
            }
        } catch {
            print("Audio session setup error: \(error)")
        }
    }
}

@available(iOS 16.1, *)
struct ContentView: View {
    @StateObject private var tracker = BitcoinTrackerManager()

    var body: some View {
        VStack(spacing: 25) {
            Text("BTC Live Tracker")
                .font(.system(size: 28, weight: .bold))
            
            Button(action: {
                tracker.isTracking ? tracker.stopTracking() : tracker.startTracking()
            }) {
                Text(tracker.isTracking ? "Stop Live Tracking" : "Start Live Tracking")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tracker.isTracking ? Color.red : Color.orange)
                    .cornerRadius(12)
            }
        }
        .padding(30)
    }
}
