import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Bindable var athlete: Athlete
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<CutPlan> { $0.isActive }) private var plans: [CutPlan]
    @Query(sort: \WeighIn.date, order: .reverse) private var weighIns: [WeighIn]

    @StateObject private var purchases = PurchaseManager.shared
    @State private var showHealthKitInfo = false
    @State private var showPaywall = false
    @State private var notificationsOn = UserDefaults.standard.bool(forKey: "settings.notifications")
    @State private var healthSyncOn = UserDefaults.standard.bool(forKey: "settings.healthSync")
    @State private var restoreMessage: String?

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    private var plan: CutPlan? { plans.first }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                healthSection
                aiSection
                subscriptionSection
                notificationSection
                legalSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showHealthKitInfo) {
                HealthKitInfoView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var profileSection: some View {
        Section {
            HStack {
                Text("Name")
                Spacer()
                TextField("Your name", text: $athlete.name)
                    .multilineTextAlignment(.trailing)
            }
            Picker("Units", selection: $athlete.unit) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.label).tag(unit)
                }
            }
            HStack {
                Text("Sport")
                Spacer()
                Text(athlete.sport.title).foregroundStyle(Theme.muted)
            }
            HStack {
                Text("Weight class")
                Spacer()
                Text("\(athlete.weightClassLabel) lbs").foregroundStyle(Theme.muted)
            }
        } header: {
            Text("Profile")
        }
    }

    private var healthSection: some View {
        Section {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("HealthKit Integration").font(.headline)
                    Text("Sync weigh-ins to Apple Health via HealthKit")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button {
                    showHealthKitInfo = true
                } label: {
                    Text("Learn More").font(.caption).foregroundStyle(Theme.brand)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)

            Toggle("Sync weigh-ins to HealthKit", isOn: $healthSyncOn)
                .tint(Theme.brand)
                .onChange(of: healthSyncOn) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "settings.healthSync")
                    if newValue {
                        Task {
                            _ = await HealthKitService.shared.requestAuthorization()
                            if let kg = await HealthKitService.shared.latestWeightKg(), kg > 0 {
                                await MainActor.run { athlete.walkWeightKg = kg }
                            }
                        }
                    }
                }
        } header: {
            HStack {
                Text("Apple Health (HealthKit)")
                Spacer()
                Image(systemName: "heart.text.square.fill").foregroundStyle(.red)
            }
        } footer: {
            Text("CutSzn uses the HealthKit framework to read your latest body mass for weigh-ins and to write weigh-ins back to the Apple Health app. This requires your explicit permission. No health data is sent to any server.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }

    private var aiSection: some View {
        Section {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.brand)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Intelligence")
                        .font(.subheadline.weight(.semibold))
                    Text(AppleIntelligenceService.isAvailable ? "Available on this device · free and offline" : "Not available · use your own API key")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            NavigationLink {
                AIProviderSettingsView()
            } label: {
                HStack {
                    Image(systemName: "key.fill").foregroundStyle(Theme.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Advanced: Configure Custom API")
                        Text(AISettingsStore.hasKey ? "Your key is stored in Keychain" : "Optional · any compatible AI provider")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        } header: {
            Text("AI")
        } footer: {
            Text("AI is optional. The glide path, protocol, safety engine, and refuel plan are 100% local and work offline.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }

    private var subscriptionSection: some View {
        Section {
            HStack {
                Text(purchases.isPro ? "Pro active" : "Free plan")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if purchases.isPro {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.brand)
                }
            }
            if !purchases.isPro {
                Button("Upgrade to Pro") { showPaywall = true }
                    .foregroundStyle(Theme.brand)
            }
            Button("Restore Purchases") {
                Task {
                    await purchases.restore()
                    restoreMessage = purchases.isPro ? "Purchases restored." : "No active purchases found."
                }
            }
            if let restoreMessage {
                Text(restoreMessage).font(.caption).foregroundStyle(Theme.muted)
            }
        } header: {
            Text("Subscription")
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle("21:00 weigh-in reminder", isOn: $notificationsOn)
                .tint(Theme.brand)
                .onChange(of: notificationsOn) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "settings.notifications")
                    if newValue {
                        Task {
                            _ = await NotificationService.shared.requestAuthorization()
                            if let plan, let snapshot = snapshot(for: plan) {
                                NotificationService.shared.scheduleDailyReminder(tomorrowTargetKg: snapshot.todayTargetKg, unit: athlete.unit)
                            }
                        }
                    } else {
                        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["cutszn.daily", "cutszn.usg"])
                    }
                }
        } header: {
            Text("Notifications")
        } footer: {
            Text("The reminder shows tomorrow's target weight so you know what to expect before you step on the scale.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }

    private func snapshot(for plan: CutPlan) -> DailySnapshot? {
        PlanCalculator.snapshot(athlete: athlete, plan: plan, weighIns: weighIns)
    }

    private var legalSection: some View {
        Section {
            Link("Privacy Policy", destination: URL(string: "https://asunnyboy861.github.io/CutSzn/privacy.html")!)
            Link("Terms of Use", destination: URL(string: "https://asunnyboy861.github.io/CutSzn/terms.html")!)
            Link("Support", destination: URL(string: "https://asunnyboy861.github.io/CutSzn/support.html")!)
            NavigationLink {
                ContactSupportView()
            } label: {
                HStack {
                    Image(systemName: "envelope.fill").foregroundStyle(Theme.brand)
                    Text("Contact Support")
                }
            }
        } header: {
            Text("Legal")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion).foregroundStyle(Theme.muted)
            }
            Text("Not medical advice. Cutting weight carries real risks. Serious dehydration can be fatal. If you feel dizzy, confused, or stop sweating, stop and seek help.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        } header: {
            Text("About")
        }
    }
}

struct HealthKitInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)
                    Text("HealthKit Integration")
                        .font(.title.bold())
                    Text("CutSzn connects to Apple Health through the HealthKit framework. We read your latest body mass so your morning weigh-in can fill in automatically, and we write your weigh-ins back so your weight history stays in one place.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    VStack(alignment: .leading, spacing: 10) {
                        bullet("You approve every HealthKit permission.")
                        bullet("Nothing is uploaded to a CutSzn server.")
                        bullet("The app works fully without HealthKit.")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemBackground))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.brand)
            Text(text).font(.subheadline)
        }
    }
}

struct AIProviderSettingsView: View {
    @State private var provider: AIProvider = AISettingsStore.settings.provider
    @State private var baseURL = AISettingsStore.settings.baseURL
    @State private var model = AISettingsStore.settings.model
    @State private var vision = AISettingsStore.settings.supportsVision
    @State private var key = AISettingsStore.apiKey ?? ""
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $provider) {
                    ForEach(AIProvider.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .onChange(of: provider) { _, newValue in
                    if newValue != .custom {
                        baseURL = newValue.baseURL
                        model = newValue.defaultModel
                        vision = newValue.visionCapable
                    }
                }

                TextField("Base URL", text: $baseURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Model", text: $model)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("API key (\(provider.keyHint))", text: $key)
                Toggle("This model can read photos", isOn: $vision)
                    .tint(Theme.brand)
            } header: {
                Text("Custom API")
            } footer: {
                Text("Your key is stored in the iOS Keychain and is never uploaded. Meal scanning requires a vision-capable model. Text-only models still work for the Corner Coach.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }

            Section {
                Button(saved ? "Saved" : "Save configuration") {
                    var settings = AISettingsStore.settings
                    settings.provider = provider
                    settings.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
                    settings.model = model.trimmingCharacters(in: .whitespaces)
                    settings.supportsVision = vision
                    AISettingsStore.settings = settings
                    AISettingsStore.apiKey = key
                    saved = true
                }
                .foregroundStyle(Theme.brand)

                Button("Remove API key", role: .destructive) {
                    AISettingsStore.clearKey()
                    key = ""
                    saved = false
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Custom API")
        .navigationBarTitleDisplayMode(.inline)
    }
}
