import SwiftUI
import SwiftData
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Notification authorization granted.")
            } else if let error = error {
                print("Notification authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotification(for sub: SubscriptionItem) {
        guard sub.notificationsEnabled else {
            cancelNotification(for: sub)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Subscription Renewal: \(sub.name)"
        content.body = "Your \(sub.billingPeriod.rawValue.lowercased()) subscription for \(sub.cost.formatted(.currency(code: sub.currencyCode))) is due tomorrow!"
        content.sound = .default
        
        // Schedule for 1 day before renewal
        let calendar = Calendar.current
        var dateComponents: DateComponents
        
        if let reminderDate = calendar.date(byAdding: .day, value: -1, to: sub.renewsOn) {
            if sub.billingPeriod == .monthly {
                dateComponents = calendar.dateComponents([.day, .hour, .minute], from: reminderDate)
            } else {
                dateComponents = calendar.dateComponents([.month, .day, .hour, .minute], from: reminderDate)
            }
            dateComponents.hour = 9
            dateComponents.minute = 0
        } else {
            return
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: sub.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelNotification(for sub: SubscriptionItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [sub.id.uuidString])
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SubscriptionItem.renewsOn) private var subscriptions: [SubscriptionItem]
    
    @State private var showingAddSheet = false
    @State private var subscriptionToEdit: SubscriptionItem?

    var groupedTotals: [String: Double] {
        // Pre-populate core currencies so the array doesn't shrink to 0 unexpectedly during view updates
        var totals: [String: Double] = ["USD": 0.0, "GBP": 0.0]
        for sub in subscriptions {
            let normalizedCost = sub.billingPeriod == .monthly ? sub.cost : (sub.cost / 12.0)
            totals[sub.currencyCode, default: 0.0] += normalizedCost
        }
        // Filter out zero-values to keep UI clean, but ensure at least one remains so ForEach doesn't panic on empty collections
        let filtered = totals.filter { $0.value > 0.0 }
        return filtered.isEmpty ? ["USD": 0.0] : filtered
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Normalized Monthly Spend")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if groupedTotals.isEmpty {
                            Text(0.0, format: .currency(code: "USD"))
                                .font(.system(size: 34, weight: .bold))
                        } else {
                            ForEach(groupedTotals.keys.sorted(), id: \.self) { code in
                                Text(groupedTotals[code]!, format: .currency(code: code))
                                    .font(.system(size: 34, weight: .bold))
                                    .contentTransition(.numericText())
                            }
                        }
                    }
                    .padding(.vertical)
                }
                
                Section("Active Subscriptions") {
                    if subscriptions.isEmpty {
                        ContentUnavailableView("No Subscriptions", systemImage: "creditcard", description: Text("Tap + to add your first subscription."))
                    } else {
                        ForEach(subscriptions) { sub in
                            SubscriptionRow(subscription: sub)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    subscriptionToEdit = sub
                                }
                        }
                        .onDelete(perform: deleteSubscriptions)
                    }
                }
            }
            .navigationTitle("SmartSubTracker")
            .onAppear {
                NotificationManager.shared.requestAuthorization()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Subscription", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                SubscriptionEditor(subscription: nil)
            }
            .sheet(item: $subscriptionToEdit) { sub in
                SubscriptionEditor(subscription: sub)
            }
        }
    }

    private func deleteSubscriptions(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                // Safeguard against index out of bounds during rapid UI updates
                guard index < subscriptions.count else { continue }
                let sub = subscriptions[index]
                NotificationManager.shared.cancelNotification(for: sub)
                modelContext.delete(sub)
            }
        }
    }
}

struct SubscriptionRow: View {
    let subscription: SubscriptionItem
    
    var body: some View {
        HStack {
            Image(systemName: subscription.iconName)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(subscription.name).font(.headline)
                    if subscription.notificationsEnabled {
                        Image(systemName: "bell.fill").font(.caption2).foregroundStyle(.orange)
                    }
                }
                Text("\(subscription.billingPeriod.rawValue) • Renews \(subscription.renewsOn.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(subscription.cost, format: .currency(code: subscription.currencyCode))
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

struct SubscriptionEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let subscription: SubscriptionItem?
    
    @State private var name: String = ""
    @State private var cost: Double = 0.0
    @State private var currencyCode: String = "USD"
    @State private var renewsOn: Date = Date()
    @State private var iconName: String = "creditcard"
    @State private var billingPeriod: BillingPeriod = .monthly
    @State private var notificationsEnabled: Bool = false
    
    let currencies = ["USD", "GBP"]
    
    init(subscription: SubscriptionItem?) {
        self.subscription = subscription
        _name = State(initialValue: subscription?.name ?? "")
        _cost = State(initialValue: subscription?.cost ?? 0.0)
        _currencyCode = State(initialValue: subscription?.currencyCode ?? "USD")
        _renewsOn = State(initialValue: subscription?.renewsOn ?? Date())
        _iconName = State(initialValue: subscription?.iconName ?? "creditcard")
        _billingPeriod = State(initialValue: subscription?.billingPeriod ?? .monthly)
        _notificationsEnabled = State(initialValue: subscription?.notificationsEnabled ?? false)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    
                    HStack {
                        TextField("Cost", value: $cost, format: .currency(code: currencyCode))
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                        Picker("", selection: $currencyCode) {
                            ForEach(currencies, id: \.self) { code in
                                Text(code).tag(code)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    
                    Picker("Billing Period", selection: $billingPeriod) {
                        ForEach(BillingPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    DatePicker("Next Renewal", selection: $renewsOn, displayedComponents: .date)
                }
                
                Section("Notifications") {
                    Toggle("Reminder (1 Day Before)", isOn: $notificationsEnabled)
                }
                
                Section("Icon") {
                    HStack {
                        Image(systemName: iconName)
                            .font(.title)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        TextField("SF Symbol Name", text: $iconName)
                            .disableAutocorrection(true)
                    }
                }
            }
            .navigationTitle(subscription == nil ? "Add Subscription" : "Edit Subscription")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 520)
#endif
    }
    
    private func save() {
        if let subscription = subscription {
            subscription.name = name
            subscription.cost = cost
            subscription.currencyCode = currencyCode
            subscription.renewsOn = renewsOn
            subscription.iconName = iconName
            subscription.billingPeriod = billingPeriod
            subscription.notificationsEnabled = notificationsEnabled
            NotificationManager.shared.scheduleNotification(for: subscription)
        } else {
            let newSub = SubscriptionItem(name: name, cost: cost, currencyCode: currencyCode, renewsOn: renewsOn, iconName: iconName, billingPeriod: billingPeriod, notificationsEnabled: notificationsEnabled)
            modelContext.insert(newSub)
            NotificationManager.shared.scheduleNotification(for: newSub)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SubscriptionItem.self, inMemory: true)
}
