import SwiftUI
import ActivityKit

public struct GroceryDeliveryAppAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var price: String
    }
    var currencyPair: String
}
