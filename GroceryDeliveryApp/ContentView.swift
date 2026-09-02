//
//  ContentView.swift
//  GroceryDeliveryApp
//

import SwiftUI
import ActivityKit
import AVFoundation
import UIKit

@available(iOS 16.1, *)
struct ContentView: View {

    @State private var activities: [Activity<GroceryDeliveryAppAttributes>] = []
    @State private var currentPriceText = "$..."
    @State private var lastUpdateText = "Waiting for price..."
    @State private var isRunning = false

    @Environment(\.scenePhase) private var scenePhase

    // نخزن الـ Task حتى نقدر نلغيه فعلياً
    @State private var priceLoopTask: Task<Void, Never>?

    // Background task من iOS
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    var body: some View {

        NavigationView {

            Form {

                // MARK: - Bitcoin

                Section {

                    Text("Bitcoin Live Dynamic Island")
                        .font(.headline)

                    Text(currentPriceText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                    Text(lastUpdateText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        startBitcoinTracker()
                    } label: {
                        Label(
                            "Start Bitcoin Live Activity",
                            systemImage: "bitcoinsign.circle.fill"
                        )
                        .font(.headline)
                    }
                    .tint(.orange)

                    Button {
                        stopBitcoinTracker()
                        endAllActivities()
                    } label: {
                        Label(
                            "End All Activities",
                            systemImage: "stop.circle.fill"
                        )
                        .font(.headline)
                    }
                    .tint(.red)
                }

                // MARK: - Active Activities

                Section {

                    if activities.isEmpty {

                        Text("No Active Bitcoin Tracker")
                            .foregroundColor(.secondary)

                    } else {

                        Text("Active Trackers")
                            .font(.headline)

                        activitiesView()
                    }
                }
            }
            .navigationTitle("Bitcoin Tracker")
        }

        // MARK: - Initial setup

        .onAppear {

            refreshActivities()

            setupAudioSession()

            startBitcoinTracker()
        }

        // MARK: - Scene changes

        .onChange(of: scenePhase) { newPhase in

            switch newPhase {

            case .active:

                print("App became active")

                endBackgroundTaskIfNeeded()

                refreshActivities()

                startBitcoinTracker()

            case .inactive:

                print("App became inactive")

            case .background:

                print("App entered background")

                /*
                 iOS يعطي التطبيق فرصة قصيرة للعمل في الخلفية.
                 هذا ليس استمراراً دائماً، لكنه أفضل من عدم طلب
                 background execution إطلاقاً.
                 */

                beginBackgroundTask()

            @unknown default:
                break
            }
        }
    }

    // MARK: - Audio Session

    /*
     تفعيل Audio Session لا يجبر iOS على إبقاء التطبيق حياً.
     نستخدمه فقط كتهيئة صحيحة في حال كان التطبيق يستخدم
     audio بشكل مشروع.
     */

    private func setupAudioSession() {

        do {

            let session = AVAudioSession.sharedInstance()

            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )

            try session.setActive(true)

            print("Audio session configured")

        } catch {

            print("Audio session error: \(error)")
        }
    }

    // MARK: - Start tracker

    private func startBitcoinTracker() {

        guard !isRunning else {
            return
        }

        isRunning = true

        priceLoopTask?.cancel()

        priceLoopTask = Task { @MainActor in

            while !Task.isCancelled && isRunning {

                await fetchBitcoinPrice()

                /*
                 محاولة كل ثانيتين.

                 ملاحظة:
                 عندما يقوم iOS بتعليق التطبيق بالخلفية،
                 هذه الـ Task قد تتوقف.
                 */

                do {

                    try await Task.sleep(
                        nanoseconds: 2_000_000_000
                    )

                } catch {

                    break
                }
            }
        }
    }

    // MARK: - Stop tracker

    private func stopBitcoinTracker() {

        isRunning = false

        priceLoopTask?.cancel()
        priceLoopTask = nil

        endBackgroundTaskIfNeeded()
    }

    // MARK: - Fetch Bitcoin price

    private func fetchBitcoinPrice() async {

        guard let url = URL(
            string:
                "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT"
        ) else {

            return
        }

        var request = URLRequest(url: url)

        request.httpMethod = "GET"

        request.timeoutInterval = 5

        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {

            let (data, response) =
                try await URLSession.shared.data(
                    for: request
                )

            guard
                let httpResponse = response as? HTTPURLResponse,
                200...299 ~= httpResponse.statusCode
            else {

                print("Binance HTTP error")

                return
            }

            guard
                let json =
                    try JSONSerialization.jsonObject(
                        with: data
                    ) as? [String: Any],

                let priceString =
                    json["price"] as? String,

                let price =
                    Double(priceString)
            else {

                print("Invalid Binance response")

                return
            }

            /*
             نخلي رقم السعر بدقة رقم عشري واحد.
             مثال:
             $77511.4
             */

            let formattedPrice =
                String(
                    format: "$%.1f",
                    price
                )

            let formatter = DateFormatter()

            formatter.locale = Locale(identifier: "en_US")

            formatter.dateFormat = "HH:mm:ss"

            let time =
                formatter.string(from: Date())

            currentPriceText = formattedPrice

            lastUpdateText =
                "Updated \(time)"

            /*
             تحديث جميع Live Activities الموجودة.
             */

            updateAllActiveLiveActivities(
                with: formattedPrice
            )

            refreshActivities()

            print("BTC:", formattedPrice)

        } catch {

            /*
             لا نوقف الـ Loop بسبب فشل طلب واحد.
             الدورة القادمة ستحاول مرة أخرى.
             */

            print(
                "Bitcoin request failed:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Update Live Activities

    private func updateAllActiveLiveActivities(
        with price: String
    ) {

        Task {

            let activeActivities =
                Activity<GroceryDeliveryAppAttributes>.activities

            for activity in activeActivities {

                let updatedStatus =
                    GroceryDeliveryAppAttributes.LiveDeliveryData(
                        courierName: price,
                        deliveryTime: .now + 3600
                    )

                await activity.update(
                    using: updatedStatus
                )
            }
        }
    }

    // MARK: - Create Live Activity

    private func createActivity() {

        let attributes =
            GroceryDeliveryAppAttributes(
                numberOfGroceyItems: 1
            )

        let contentState =
            GroceryDeliveryAppAttributes.LiveDeliveryData(
                courierName: currentPriceText,
                deliveryTime: .now + 3600
            )

        do {

            let activity =
                try Activity<
                    GroceryDeliveryAppAttributes
                >.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: .token
                )

            print(
                "Live Activity started:",
                activity.id
            )

            /*
             مهم جداً:
             نقرأ Push Token إذا احتجناه لاحقاً لـ APNs.
             */

            Task {

                for await tokenData
                    in activity.pushTokenUpdates {

                    let token =
                        tokenData
                            .map {
                                String(
                                    format: "%02x",
                                    $0
                                )
                            }
                            .joined()

                    print(
                        "Live Activity Push Token:",
                        token
                    )
                }
            }

            refreshActivities()

        } catch {

            print(
                "Failed to create Live Activity:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Start button

    private func startBitcoinTrackerAndActivity() {

        createActivity()

        startBitcoinTracker()

        refreshActivities()
    }

    private func startBitcoinTracker() {

        /*
         إذا الـ Activity غير موجودة، ننشئ واحدة.
         */

        if Activity<GroceryDeliveryAppAttributes>
            .activities
            .isEmpty {

            createActivity()
        }

        guard !isRunning else {
            return
        }

        isRunning = true

        priceLoopTask?.cancel()

        priceLoopTask = Task { @MainActor in

            while !Task.isCancelled && isRunning {

                await fetchBitcoinPrice()

                do {

                    try await Task.sleep(
                        nanoseconds: 2_000_000_000
                    )

                } catch {

                    break
                }
            }
        }
    }

    // MARK: - Public start

    private func startTrackerFromButton() {

        createActivity()

        startBitcoinTracker()

        refreshActivities()
    }

    // MARK: - End activities

    private func endAllActivities() {

        Task {

            let activeActivities =
                Activity<GroceryDeliveryAppAttributes>.activities

            for activity in activeActivities {

                await activity.end(
                    dismissalPolicy: .immediate
                )
            }

            await MainActor.run {

                refreshActivities()
            }
        }
    }

    // MARK: - Refresh activities

    private func refreshActivities() {

        var current =
            Activity<GroceryDeliveryAppAttributes>.activities

        current.sort {
            $0.id > $1.id
        }

        activities = current
    }

    // MARK: - Background task

    private func beginBackgroundTask() {

        guard backgroundTaskID == .invalid else {
            return
        }

        backgroundTaskID =
            UIApplication.shared.beginBackgroundTask(
                withName: "BitcoinPriceUpdate"
            ) {

                /*
                 iOS أخبرنا أن وقت الـ background انتهى.
                 */

                Task { @MainActor in

                    self.endBackgroundTaskIfNeeded()
                }
            }

        print(
            "Background task started:",
            backgroundTaskID.rawValue
        )
    }

    private func endBackgroundTaskIfNeeded() {

        guard backgroundTaskID != .invalid else {
            return
        }

        UIApplication.shared.endBackgroundTask(
            backgroundTaskID
        )

        backgroundTaskID = .invalid

        print("Background task ended")
    }
}

// MARK: - Activity List

@available(iOS 16.1, *)
extension ContentView {

    @ViewBuilder
    private func activitiesView() -> some View {

        ScrollView {

            VStack(spacing: 12) {

                ForEach(
                    activities,
                    id: \.id
                ) { activity in

                    let priceValue =
                        activity.contentState.courierName

                    HStack {

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {

                            Text("BTC")

                                .font(.headline)

                            Text(priceValue)

                                .font(
                                    .system(
                                        size: 20,
                                        weight: .bold
                                    )
                                )
                                .foregroundColor(.green)
                        }

                        Spacer()

                        Button {

                            Task {

                                await activity.end(
                                    dismissalPolicy: .immediate
                                )

                                refreshActivities()
                            }

                        } label: {

                            Image(
                                systemName:
                                    "xmark.circle.fill"
                            )
                            .font(.title2)
                            .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}