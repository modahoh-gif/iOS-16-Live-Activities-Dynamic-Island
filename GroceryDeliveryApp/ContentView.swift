import SwiftUI
import ActivityKit

@available(iOS 16.1, *)
struct ContentView: View {

    @State private var activities:
        [Activity<GroceryDeliveryAppAttributes>] = []

    @State private var currentPriceText = "$..."

    @State private var isRunning = false

    @State private var priceLoopTask:
        Task<Void, Never>?

    @Environment(\.scenePhase)
    private var scenePhase

    var body: some View {

        NavigationView {

            Form {

                Section {

                    Text("Bitcoin Live Dynamic Island")
                        .font(.headline)

                    Text(currentPriceText)
                        .font(
                            .system(
                                size: 32,
                                weight: .bold
                            )
                        )
                        .foregroundColor(.green)

                    Button {

                        createActivity()
                        startBitcoinTracker()

                    } label: {

                        Text("Start Bitcoin Live Activity")
                            .font(.headline)
                    }
                    .tint(.orange)

                    Button {

                        stopBitcoinTracker()
                        endAllActivities()

                    } label: {

                        Text("End All Activities")
                            .font(.headline)
                    }
                    .tint(.red)
                }

                Section {

                    if !activities.isEmpty {

                        Text("Active Trackers")
                            .font(.headline)

                        activitiesView()
                    }
                }
            }
            .navigationTitle("Bitcoin Tracker")
        }

        .onAppear {

            refreshActivities()
        }

        .onChange(of: scenePhase) { phase in

            if phase == .active {

                refreshActivities()

                /*
                 إذا رجع التطبيق للواجهة،
                 نستأنف التحديث.
                 */

                startBitcoinTracker()
            }
        }
    }

    // MARK: - Bitcoin Loop

    private func startBitcoinTracker() {

        guard !isRunning else {
            return
        }

        isRunning = true

        priceLoopTask?.cancel()

        priceLoopTask = Task {

            while !Task.isCancelled {

                await fetchBitcoinPrice()

                do {

                    try await Task.sleep(
                        nanoseconds:
                            2_000_000_000
                    )

                } catch {

                    break
                }
            }
        }
    }

    // MARK: - Stop

    private func stopBitcoinTracker() {

        isRunning = false

        priceLoopTask?.cancel()

        priceLoopTask = nil
    }

    // MARK: - Binance

    private func fetchBitcoinPrice() async {

        guard let url = URL(
            string:
                "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT"
        ) else {
            return
        }

        var request =
            URLRequest(url: url)

        request.httpMethod = "GET"

        request.timeoutInterval = 5

        request.cachePolicy =
            .reloadIgnoringLocalCacheData

        do {

            let (
                data,
                response
            ) =
                try await URLSession.shared.data(
                    for: request
                )

            guard
                let http =
                    response as? HTTPURLResponse,
                200...299 ~= http.statusCode
            else {
                return
            }

            guard
                let json =
                    try JSONSerialization
                    .jsonObject(
                        with: data
                    ) as? [String: Any],

                let value =
                    json["price"] as? String
            else {
                return
            }

            let price =
                Double(value) ?? 0

            let formatted =
                String(
                    format: "$%.1f",
                    price
                )

            await MainActor.run {

                currentPriceText =
                    formatted
            }

            updateLiveActivities(
                price: formatted
            )

        } catch {

            print(
                "BTC error:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Live Activity Update

    private func updateLiveActivities(
        price: String
    ) {

        Task {

            let current =
                Activity<
                    GroceryDeliveryAppAttributes
                >.activities

            for activity in current {

                let state =
                    GroceryDeliveryAppAttributes
                    .LiveDeliveryData(
                        courierName: price,
                        deliveryTime:
                            .now + 3600
                    )

                /*
                 update(using:) موجود في مشروعك القديم،
                 لكنه deprecated في SDK الجديد.
                 نستخدم update(_:) عندما يكون متاحاً.
                 */

                if #available(
                    iOS 16.2,
                    *
                ) {

                    await activity.update(
                        ActivityContent(
                            state: state,
                            staleDate:
                                .now + 30
                        )
                    )

                } else {

                    await activity.update(
                        using: state
                    )
                }
            }
        }
    }

    // MARK: - Create Activity

    private func createActivity() {

        /*
         لا تنشئ Activity ثانية إذا كانت
         موجودة أصلاً.
         */

        if !Activity<
            GroceryDeliveryAppAttributes
        >.activities.isEmpty {

            refreshActivities()

            return
        }

        let attributes =
            GroceryDeliveryAppAttributes(
                numberOfGroceyItems: 1
            )

        let state =
            GroceryDeliveryAppAttributes
            .LiveDeliveryData(
                courierName:
                    currentPriceText,
                deliveryTime:
                    .now + 3600
            )

        do {

            let activity =
                try Activity<
                    GroceryDeliveryAppAttributes
                >.request(
                    attributes: attributes,
                    content:
                        ActivityContent(
                            state: state,
                            staleDate:
                                .now + 30
                        ),
                    pushType: .token
                )

            print(
                "Activity:",
                activity.id
            )

            /*
             هذا مهم جداً للمستقبل:
             Push Token يمكن أن يتغير.
             */

            Task {

                for await token
                    in activity.pushTokenUpdates {

                    let tokenString =
                        token.map {
                            String(
                                format: "%02x",
                                $0
                            )
                        }
                        .joined()

                    print(
                        "LIVE ACTIVITY TOKEN:",
                        tokenString
                    )
                }
            }

            refreshActivities()

        } catch {

            print(
                "Activity error:",
                error.localizedDescription
            )
        }
    }

    // MARK: - End

    private func endAllActivities() {

        Task {

            for activity
                in Activity<
                    GroceryDeliveryAppAttributes
                >.activities {

                await activity.end(
                    dismissalPolicy:
                        .immediate
                )
            }

            await MainActor.run {

                refreshActivities()
            }
        }
    }

    // MARK: - Refresh

    private func refreshActivities() {

        activities =
            Activity<
                GroceryDeliveryAppAttributes
            >.activities
    }

    // MARK: - List

    @ViewBuilder
    private func activitiesView() -> some View {

        ForEach(
            activities,
            id: \.id
        ) { activity in

            HStack {

                Text(
                    activity
                        .contentState
                        .courierName
                )
                .font(.headline)

                Spacer()

                Button("End") {

                    Task {

                        await activity.end(
                            dismissalPolicy:
                                .immediate
                        )

                        refreshActivities()
                    }
                }
                .foregroundColor(.red)
            }
        }
    }
}