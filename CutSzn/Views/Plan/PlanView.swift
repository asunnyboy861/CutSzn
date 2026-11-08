import SwiftUI
import SwiftData
import Charts

struct PlanView: View {
    @Bindable var athlete: Athlete
    @Bindable var plan: CutPlan
    @Query(sort: \WeighIn.date, order: .reverse) private var weighIns: [WeighIn]
    @Query(sort: \USGLog.date, order: .reverse) private var usgLogs: [USGLog]
    @Query(sort: \CutPlan.createdAt, order: .reverse) private var allPlans: [CutPlan]

    @State private var showUSGSheet = false
    @State private var usgValue = ""

    private var snapshot: DailySnapshot {
        PlanCalculator.snapshot(athlete: athlete, plan: plan, weighIns: weighIns)
    }

    private var path: [DayTarget] {
        CutPlanEngine.glidePath(currentKg: snapshot.currentKg, targetKg: plan.targetWeightKg, weighInDate: plan.weighInDate)
    }

    private var pastPlans: [CutPlan] {
        allPlans.filter { !$0.isActive }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    chartCard
                    protocolTable
                    emergencySection
                    usgSection
                    archiveSection
                    disclaimer
                }
                .padding(20)
                .padding(.bottom, 64)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showUSGSheet) {
                usgSheet
                    .presentationDetents([.height(320)])
            }
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Glide path")
                    .font(.headline)
                Spacer()
                Text("\(snapshot.daysOut) days out")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            Chart(path) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", UnitConversion.number(point.targetKg, unit: athlete.unit))
                )
                .foregroundStyle(Theme.brand)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Floor", UnitConversion.number(plan.targetWeightKg, unit: athlete.unit)),
                    yEnd: .value("Weight", UnitConversion.number(point.targetKg, unit: athlete.unit))
                )
                .foregroundStyle(Theme.brand.opacity(0.12))

                RuleMark(y: .value("Limit", UnitConversion.number(plan.targetWeightKg, unit: athlete.unit)))
                    .foregroundStyle(Theme.amber)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartYScale(domain: chartDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(path.count / 4, 1))) { _ in
                    AxisGridLine().foregroundStyle(Color(uiColor: .tertiarySystemFill))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Color(uiColor: .tertiarySystemFill))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text("\(Int(number))")
                        }
                    }
                }
            }
            .frame(height: 220)

            HStack(spacing: 16) {
                Label("Glide path", systemImage: "line.diagonal")
                Label("Class limit", systemImage: "flag.fill")
            }
            .font(.caption2)
            .foregroundStyle(Theme.muted)

            HStack {
                statBlock(title: "Start", value: UnitConversion.string(plan.startWeightKg, unit: athlete.unit, decimals: 1))
                statBlock(title: "Today", value: UnitConversion.string(snapshot.todayTargetKg, unit: athlete.unit, decimals: 1))
                statBlock(title: "Limit", value: UnitConversion.string(plan.targetWeightKg, unit: athlete.unit, decimals: 1))
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var chartDomain: ClosedRange<Double> {
        let values = path.map { UnitConversion.number($0.targetKg, unit: athlete.unit) }
        let low = min((values.min() ?? 100), UnitConversion.number(plan.targetWeightKg, unit: athlete.unit)) - 3
        let high = (values.max() ?? 200) + 3
        return low...max(high, low + 10)
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.muted)
            Text("\(value) \(athlete.unit.label)")
                .font(.footnote.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12))
    }

    private var protocolTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fight-week protocol")
                .font(.headline)
            Text("Water, sodium, carbs, and fiber targets change by day. Today's numbers are on the Today tab.")
                .font(.caption)
                .foregroundStyle(Theme.muted)

            HStack {
                Text("DAY").frame(width: 86, alignment: .leading)
                Text("WATER").frame(maxWidth: .infinity, alignment: .leading)
                Text("SODIUM").frame(maxWidth: .infinity, alignment: .leading)
                Text("CARBS").frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.muted)

            ForEach(0..<5, id: \.self) { offset in
                let days = max(snapshot.daysOut - offset, 0)
                let targets = ProtocolCurve.targets(daysUntilWeighIn: days, weightKg: snapshot.currentKg)
                HStack {
                    Text(dayLabel(days))
                        .font(.caption.weight(.semibold))
                        .frame(width: 86, alignment: .leading)
                    Text("\(targets.waterML) ml")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(targets.sodiumMG) mg")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(targets.carbsG) g")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption2)
                .foregroundStyle(offset == 0 ? Theme.brand : Theme.muted)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private func dayLabel(_ days: Int) -> String {
        switch days {
        case 0: return "Weigh-in"
        case 1: return "Tomorrow"
        case 2...3: return "T−\(days) cut"
        case 4...6: return "T−\(days) taper"
        default: return "T−\(days) load"
        }
    }

    private var emergencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Final 48 hours")
                .font(.headline)
            Text(snapshot.emergencyStage == 0
                 ? "Emergency mode unlocks in the final 48 hours before weigh-in."
                 : SafetyEngine.stageTitle(snapshot.emergencyStage))
                .font(.caption)
                .foregroundStyle(Theme.muted)

            if snapshot.emergencyStage > 0 {
                NavigationLink {
                    EmergencyModeView(athlete: athlete, plan: plan, stage: snapshot.emergencyStage)
                } label: {
                    HStack {
                        Image(systemName: "bolt.heart.fill")
                        Text("Open emergency mode")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                    .padding(14)
                    .background(Theme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var usgSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("USG compliance")
                    .font(.headline)
                Spacer()
                Button("Log") {
                    showUSGSheet = true
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.brand)
            }
            Text("\(plan.org.displayName) limit: \(String(format: "%.3f", plan.org.usgLimit)). NFHS and NCAA require this check during the season.")
                .font(.caption)
                .foregroundStyle(Theme.muted)

            if usgLogs.isEmpty {
                Text("No test strips logged yet.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 8)
            } else {
                ForEach(usgLogs.prefix(5)) { log in
                    HStack {
                        Text(log.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Text(String(format: "%.3f", log.value))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        Spacer()
                        Text(SafetyEngine.usgPassed(log.value, org: plan.org) ? "PASS" : "FAIL")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(SafetyEngine.usgPassed(log.value, org: plan.org) ? Theme.brand : Theme.danger)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var usgSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("USG test strip value")
                    .font(.headline)
                TextField("1.020", text: $usgValue)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                Text("Enter 1.005–1.035. Over 1.030 is a forced hydration warning.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Button {
                    saveUSG()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.black)
                }
                Spacer()
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showUSGSheet = false }
                }
            }
        }
    }

    private func saveUSG() {
        guard let value = Double(usgValue), value > 0 else { return }
        let log = USGLog(value: value)
        context.insert(log)
        try? context.save()
        usgValue = ""
        showUSGSheet = false
    }

    @Environment(\.modelContext) private var context

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Season archive")
                .font(.headline)
            if pastPlans.isEmpty {
                Text("Finished cuts will be kept here.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(pastPlans.prefix(5)) { past in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(past.madeWeight ? "Made weight" : "Cut ended")
                                .font(.subheadline.weight(.semibold))
                            Text(past.weighInDate, format: .dateTime.month(.abbreviated).day().year())
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text("\(UnitConversion.string(past.startWeightKg, unit: athlete.unit, decimals: 1)) → \(UnitConversion.string(past.targetWeightKg, unit: athlete.unit, decimals: 1))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var disclaimer: some View {
        Text("Not medical advice. USG limits and weekly caps follow NFHS and NCAA guidance.")
            .font(.caption2)
            .foregroundStyle(Theme.muted)
    }
}

struct EmergencyModeView: View {
    @Bindable var athlete: Athlete
    @Bindable var plan: CutPlan
    var stage: Int

    @Environment(\.dismiss) private var dismiss
    @State private var secondsLeft = 900
    @State private var running = false
    @State private var timerTask: Task<Void, Never>?

    private var gapPct: Double {
        guard let latest = latestWeighInKg else { return 0 }
        return (latest - plan.targetWeightKg) / latest * 100
    }

    @Query(sort: \WeighIn.date, order: .reverse) private var weighIns: [WeighIn]
    private var latestWeighInKg: Double? { weighIns.first?.weightKg }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                switch stage {
                case 3: stageThree
                case 2: stageTwo
                default: stageOne
                }
                safetyFooter
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Emergency mode")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stopTimer() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(SafetyEngine.stageTitle(stage))
                .font(.title2.bold())
            Text(String(format: "Current gap: %.1f%% of body weight.", gapPct))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }

    private var stageOne: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Micro-adjust rules")
                .font(.headline)
            rule("Water: only the amount on today's card, sipped slowly.")
            rule("No added sodium. No sports drinks.")
            rule("Low-residue food only: white rice, lean protein, no vegetables with skins.")
            rule("Weigh again tomorrow morning. Do not stack methods.")
        }
        .padding(16)
        .background(Theme.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
    }

    private var stageTwo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sauna rounds")
                .font(.headline)
            Text("10–15 minutes per round, then a full cooldown. Hard cap: 30 minutes today.")
                .font(.caption)
                .foregroundStyle(Theme.muted)

            ZStack {
                Circle()
                    .stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(secondsLeft) / 900)
                    .stroke(Theme.amber, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack {
                    Text(String(format: "%02d:%02d", secondsLeft / 60, secondsLeft % 60))
                        .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    Text(running ? "In the round" : "Ready")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 180, height: 180)
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Button(running ? "Stop" : "Start round") {
                    running ? stopTimer() : startTimer()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Theme.amber.opacity(running ? 0.2 : 1), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(running ? Theme.amber : .black)
                .disabled(stage == 3)
            }

            rule("Cool down fully between rounds. Sit, feet elevated, sip water.")
            rule("Stop immediately if you feel dizzy, get chills, or stop sweating.")
        }
        .padding(16)
        .background(Theme.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
    }

    private var stageThree: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("We will not build this cut", systemImage: "hand.raised.fill")
                .font(.headline)
                .foregroundStyle(Theme.danger)
            Text("The gap is over 5% of your body weight. Acute dehydration at this level has caused deaths in combat sports.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            rule("Move up one weight class.")
            rule("Postpone the weigh-in by at least a week.")
            rule("Talk to your coach or athletic trainer today.")
        }
        .padding(16)
        .background(Theme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 5)).padding(.top, 6)
            Text(text).font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var safetyFooter: some View {
        Text("Not medical advice. If you feel faint or confused, stop and get help.")
            .font(.caption2)
            .foregroundStyle(Theme.muted)
    }

    private func startTimer() {
        running = true
        secondsLeft = 900
        timerTask = Task {
            while !Task.isCancelled && secondsLeft > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                await MainActor.run { secondsLeft -= 1 }
            }
            await MainActor.run { running = false }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        running = false
    }
}
