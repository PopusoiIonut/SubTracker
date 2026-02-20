import Foundation
import SwiftData

enum BillingPeriod: String, Codable, CaseIterable {
    case monthly = "Monthly"
    case annually = "Annually"
}

@Model
final class SubscriptionItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var cost: Double
    var currencyCode: String
    var renewsOn: Date
    var iconName: String
    var billingPeriod: BillingPeriod
    var notificationsEnabled: Bool
    
    init(name: String = "New Subscription", 
         cost: Double = 0.0, 
         currencyCode: String = "USD",
         renewsOn: Date = Date(), 
         iconName: String = "creditcard",
         billingPeriod: BillingPeriod = .monthly,
         notificationsEnabled: Bool = false) {
        self.id = UUID()
        self.name = name
        self.cost = cost
        self.currencyCode = currencyCode
        self.renewsOn = renewsOn
        self.iconName = iconName
        self.billingPeriod = billingPeriod
        self.notificationsEnabled = notificationsEnabled
    }
}
