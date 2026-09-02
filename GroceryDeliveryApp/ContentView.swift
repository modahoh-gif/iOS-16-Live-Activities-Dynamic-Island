import SwiftUI
import ActivityKit

// 1. إنشاء هيكل مخصص للبتكوين بدلاً من تطبيق التوصيل
struct BitcoinTrackerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentPrice: String
    }
    var currencyName: String
}

@available(iOS 16.1, *)
struct ContentView: View {
    @State private var currentActivity: Activity<BitcoinTrackerAttributes>?
    @State private var isTracking = false
    @State private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    var body: some View {
        VStack(spacing: 20) {
            Text("متتبع البتكوين")
                .font(.largeTitle)
            
            Button(action: {
                isTracking ? stopTracking() : startTracking()
            }) {
                Text(isTracking ? "إيقاف التتبع" : "بدء التتبع")
                    .padding()
                    .background(isTracking ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    // بدء الـ Activity
    func startTracking() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = BitcoinTrackerAttributes(currencyName: "Bitcoin")
        let state = BitcoinTrackerAttributes.ContentState(currentPrice: "جاري الجلب...")
        
        do {
            // حل مشكلة توافق الإصدارات (iOS 16.2 vs iOS 16.1)
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: state, staleDate: nil)
                currentActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } else {
                currentActivity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            }
            
            isTracking = true
            startFetchingPrice()
        } catch {
            print("Activity error:", error.localizedDescription)
        }
    }
    
    // إيقاف الـ Activity
    func stopTracking() {
        Task {
            let finalState = BitcoinTrackerAttributes.ContentState(currentPrice: "توقف التتبع")
            
            if #available(iOS 16.2, *) {
                let finalContent = ActivityContent(state: finalState, staleDate: nil)
                await currentActivity?.end(finalContent, dismissalPolicy: .immediate)
            } else {
                await currentActivity?.end(using: finalState, dismissalPolicy: .immediate)
            }
            
            isTracking = false
            endBackgroundTask()
        }
    }
    
    // حلقة جلب السعر مع تفعيل مهمة الخلفية المؤقتة
    func startFetchingPrice() {
        registerBackgroundTask()
        
        Task {
            while isTracking {
                let newPrice = await fetchBitcoinPrice()
                updateActivity(with: newPrice)
                
                do {
                    // الانتظار لمدة ثانيتين
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    break
                }
            }
        }
    }
    
    // تحديث البيانات في Dynamic Island
    func updateActivity(with price: String) {
        Task {
            let updatedState = BitcoinTrackerAttributes.ContentState(currentPrice: price)
            
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: updatedState, staleDate: nil)
                await currentActivity?.update(content)
            } else {
                await currentActivity?.update(using: updatedState)
            }
        }
    }
    
    // دالة وهمية لجلب السعر (استبدلها بالـ API الحقيقي)
    func fetchBitcoinPrice() async -> String {
        let randomPrice = Int.random(in: 60000...65000)
        return "$\(randomPrice)"
    }
    
    // طلب صلاحية العمل في الخلفية (يمنحك حوالي 30 ثانية فقط)
    func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask {
            endBackgroundTask()
        }
    }
    
    func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
