import SwiftUI
import SwiftData

enum Theme {
    static let brand = Color(red: 0.0, green: 0.902, blue: 0.463)
    static let brandDim = Color(red: 0.0, green: 0.902, blue: 0.463).opacity(0.16)
    static let amber = Color(red: 1.0, green: 0.702, blue: 0.0)
    static let danger = Color(red: 1.0, green: 0.231, blue: 0.188)
    static let card = Color(uiColor: .secondarySystemBackground)
    static let elevated = Color(uiColor: .tertiarySystemBackground)
    static let muted = Color(uiColor: .secondaryLabel)

    static func verdictColor(_ kind: CutVerdict.Kind) -> Color {
        switch kind {
        case .green: return brand
        case .yellow: return amber
        case .red: return danger
        }
    }

    static func verdictIcon(_ kind: CutVerdict.Kind) -> String {
        switch kind {
        case .green: return "checkmark.circle.fill"
        case .yellow: return "exclamationmark.triangle.fill"
        case .red: return "hand.raised.fill"
        }
    }
}

struct RootView: View {
    @Query private var athletes: [Athlete]

    var body: some View {
        Group {
            if let athlete = athletes.first, athlete.onboarded {
                MainTabView(athlete: athlete)
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct MainTabView: View {
    @Bindable var athlete: Athlete
    @Query(filter: #Predicate<CutPlan> { $0.isActive }, sort: \CutPlan.createdAt, order: .reverse) private var plans: [CutPlan]
    @State private var showSettings = false
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            Group {
                if let plan = plans.first {
                    TodayView(athlete: athlete, plan: plan)
                } else {
                    StartCutEmptyView(athlete: athlete)
                }
            }
            .tabItem { Label("Today", systemImage: "gauge.with.dots.needle.67percent") }
            .tag(0)

            Group {
                if let plan = plans.first {
                    PlanView(athlete: athlete, plan: plan)
                } else {
                    StartCutEmptyView(athlete: athlete)
                }
            }
            .tabItem { Label("Plan", systemImage: "chart.line.downtrend.xyaxis") }
            .tag(1)

            TeamView(athlete: athlete, plan: plans.first)
                .tabItem { Label("Team", systemImage: "person.2.fill") }
                .tag(2)
        }
        .tint(Theme.brand)
        .onAppear {
            #if DEBUG
            if CommandLine.arguments.contains("-demoTab") {
                selection = DemoSeed.tabIndex
            }
            #endif
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(12)
            }
            .accessibilityLabel("Settings")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(athlete: athlete)
        }
    }
}

struct StartCutEmptyView: View {
    @Bindable var athlete: Athlete
    @Environment(\.modelContext) private var context
    @State private var weightText = ""
    @State private var days = 14
    @State private var verdict: CutVerdict?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.brand)
                Text("Start your next cut")
                    .font(.title2.bold())
                Text("Enter your current weight and how many days you have. We will build the glide path.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    HStack {
                        Text("Current weight")
                        Spacer()
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text(athlete.unit.label)
                            .foregroundStyle(Theme.muted)
                    }
                    Stepper("Weigh-in in \(days) days", value: $days, in: 1...120)
                }
                .padding()
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))

                if let verdict {
                    VerdictBanner(verdict: verdict)
                }

                Button(action: evaluate) {
                    Text("Check this cut")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.black)
                }
                .disabled(weightText.isEmpty)

                if let verdict, verdict.kind != .red {
                    Button(action: startPlan) {
                        Text("Start this plan")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.brandDim, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(Theme.brand)
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.card.opacity(0.35))
            .navigationTitle("New cut")
        }
    }

    private var currentKg: Double {
        UnitConversion.toKg(Double(weightText) ?? 0, unit: athlete.unit)
    }

    private func evaluate() {
        verdict = CutPlanEngine.verdict(currentKg: currentKg, targetKg: athlete.targetWeightKg, days: days, org: athlete.org)
    }

    private func startPlan() {
        let plan = CutPlan(startWeightKg: currentKg, targetWeightKg: athlete.targetWeightKg,
                           weighInDate: Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date(),
                           org: athlete.org)
        plan.verdictRaw = verdict?.kind == .green ? VerdictKind.green.rawValue : VerdictKind.yellow.rawValue
        context.insert(plan)
        athlete.walkWeightKg = currentKg
        try? context.save()
    }
}

struct VerdictBanner: View {
    var verdict: CutVerdict

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: Theme.verdictIcon(verdict.kind))
                Text(verdict.bannerText)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(Theme.verdictColor(verdict.kind))

            Text(verdict.title)
                .font(.headline)
                .foregroundStyle(.primary)

            if !verdict.rules.isEmpty {
                ForEach(verdict.rules, id: \.self) { rule in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "circle.fill").font(.system(size: 5)).padding(.top, 6)
                        Text(rule).font(.caption).foregroundStyle(Theme.muted)
                    }
                }
            }
            if !verdict.reason.isEmpty {
                Text(verdict.reason).font(.footnote).foregroundStyle(Theme.muted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.verdictColor(verdict.kind).opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}
