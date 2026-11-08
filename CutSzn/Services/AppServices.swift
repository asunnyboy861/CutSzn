import Foundation
import HealthKit
import UserNotifications
import WidgetKit

final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var isAuthorized: Bool {
        guard isAvailable, let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return false }
        return store.authorizationStatus(for: type) == .sharingAuthorized
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable, let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return false }
        do {
            try await store.requestAuthorization(toShare: [type], read: [type])
            return true
        } catch {
            return false
        }
    }

    func latestWeightKg() async -> Double? {
        guard isAvailable, let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    func save(weightKg: Double) async {
        guard isAvailable, let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        try? await store.save(sample)
    }
}

final class NotificationService {
    static let shared = NotificationService()

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleDailyReminder(tomorrowTargetKg: Double, unit: WeightUnit) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["cutszn.daily"])

        let content = UNMutableNotificationContent()
        content.title = "Tomorrow's number"
        content.body = "\(UnitConversion.string(tomorrowTargetKg, unit: unit)) \(unit.label). Morning weight first, then breakfast."
        content.sound = .default

        var components = DateComponents()
        components.hour = 21
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "cutszn.daily", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleFightWeekUSGReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["cutszn.usg"])

        let content = UNMutableNotificationContent()
        content.title = "USG check"
        content.body = "Log this morning's test strip before you drink anything."
        content.sound = .default

        var components = DateComponents()
        components.hour = 7
        components.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "cutszn.usg", content: content, trigger: trigger)
        center.add(request)
    }

    func cancelFightWeekUSGReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["cutszn.usg"])
    }
}

enum WidgetSnapshotService {
    static let suiteName = "group.com.zzoutuo.CutSzn"

    static func update(tomorrowTargetKg: Double, daysOut: Int, unit: WeightUnit) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set("\(UnitConversion.string(tomorrowTargetKg, unit: unit)) \(unit.label)", forKey: "widget.tomorrowTarget")
        defaults.set(daysOut, forKey: "widget.daysOut")
        defaults.set(Date().timeIntervalSince1970, forKey: "widget.updatedAt")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct FeedbackRequest: Codable {
    let name: String
    let email: String
    let subject: String
    let message: String
    let app_name: String
}

struct FeedbackResponse: Codable {
    let success: Bool?
    let error: String?
    let id: Int?
}

enum FeedbackService {
    static func send(name: String, email: String, subject: String, message: String, appName: String) async throws {
        guard let url = URL(string: "https://msg.calcs.top/api/feedback") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let body = FeedbackRequest(name: name, email: email, subject: subject, message: message, app_name: appName)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try? JSONDecoder().decode(FeedbackResponse.self, from: data)
        if let error = decoded?.error, !error.isEmpty {
            throw NSError(domain: "Feedback", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
    }
}

enum AIQuota {
    private static var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    static func scansUsed(isPro: Bool) -> Int {
        UserDefaults.standard.integer(forKey: "quota.scan.\(monthKey)")
    }

    static func coachUsed(isPro: Bool) -> Int {
        UserDefaults.standard.integer(forKey: "quota.coach.\(monthKey)")
    }

    static func scanLimit(isPro: Bool) -> Int { isPro ? 30 : 3 }
    static func coachLimit(isPro: Bool) -> Int { isPro ? 60 : 5 }

    static func canScan(isPro: Bool) -> Bool {
        scansUsed(isPro: isPro) < scanLimit(isPro: isPro)
    }

    static func canCoach(isPro: Bool) -> Bool {
        coachUsed(isPro: isPro) < coachLimit(isPro: isPro)
    }

    static func incrementScan() {
        let key = "quota.scan.\(monthKey)"
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }

    static func incrementCoach() {
        let key = "quota.coach.\(monthKey)"
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: "quota.scan.\(monthKey)")
        UserDefaults.standard.removeObject(forKey: "quota.coach.\(monthKey)")
    }
}
