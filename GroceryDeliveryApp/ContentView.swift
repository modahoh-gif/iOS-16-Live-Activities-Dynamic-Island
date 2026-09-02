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

    // MARK: - Body

    var body: some View {

        NavigationView {

            Form {

                // MARK: Bitcoin Section

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

                // MARK: Active Activities

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

        // MARK: App Appeared

        .onAppear {
            refreshActivities()
        }

        // MARK: Scene Phase

        .onChange(of: scenePhase) { phase in

            if phase == .active {

                refreshActivities()

                if !isRunning {
                    startBitcoinTracker()
                }
            }
        }
    }

    // MARK: - Start Bitcoin Tracker

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
                        nanoseconds: 2_000_000_000
                    )

                } catch {

                    break
                }
            }
        }
    }

    // MARK: - Stop Bitcoin Tracker

    private func stopBitcoinTracker() {

        isRunning = false

        priceLoopTask?.cancel()

        priceLoopTask = nil
    }

    // MARK: - Fetch Bitcoin Price

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

        request.cachePolicy =
            .reloadIgnoringLocalCacheData

        do {

            let (data, response) =
                try await URLSession.shared.data(
                    for: request
                )

            guard
                let httpResponse =
                    response as? HTTPURLResponse,
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

                let value =
                    json["price"] as? String,

                let price =
                    Double(value)
            else {

                print("Invalid Binance response")
                return
            }

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

            if !Task.isCancelled {

                print(
                    "BTC error:",
                    error.localizedDescription
                )
            }
        }
    }

    // MARK: - Update Live Activities

    private func updateLiveActivities(
        price: String
    ) {

        Task {

            let currentActivities =
                Activity<
                    GroceryDeliveryAppAttributes
                >.activities

            for activity in currentActivities {

                let state =
                    GroceryDeliveryAppAttributes
                    .LiveDeliveryData(
                        courierName: price,
                        deliveryTime:
                            .now + 3600
                    )

                if #available(iOS 16.2, *) {

                    let content =
                        ActivityContent(
                            state: state,
                            staleDate:
                                .now + 30
                        )

                    await activity.update(
                        content
                    )

                } else {

                    await activity.update(
                        using: state
                    )
                }
            }

            await MainActor.run {

                refreshActivities()
            }
        }
    }

    // MARK: - Create Live Activity

    private func createActivity() {

        let existingActivities =
            Activity<
                GroceryDeliveryAppAttributes
            >.activities

        // إذا يوجد Live Activity بالفعل
        // لا ننشئ واحدة جديدة.

        if !existingActivities.isEmpty {

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
                    pushType: nil
                )

            print(
                "Activity created:",
                activity.id
            )

            refreshActivities()

        } catch {

            print(
                "Activity error:",
                error.localizedDescription
            )
        }
    }

    // MARK: - End All Activities

    private func endAllActivities() {

        Task {

            let currentActivities =
                Activity<
                    GroceryDeliveryAppAttributes
                >.activities

            for activity in currentActivities {

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

    // MARK: - Refresh Activities

    private func refreshActivities() {

        activities =
            Activity<
                GroceryDeliveryAppAttributes
            >.activities
    }

    // MARK: - Activities List

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

                        await MainActor.run {

                            refreshActivities()
                        }
                    }
                }
                .foregroundColor(.red)
            }
        }
    }
}