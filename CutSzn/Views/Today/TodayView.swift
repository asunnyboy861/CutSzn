import SwiftUI
import SwiftData

struct TodayView: View {
    @Bindable var athlete: Athlete
    @Bindable var plan: CutPlan
    @Query(sort: \WeighIn.date, order: .reverse) private var weighIns: [WeighIn]
    @Query private var progressRows: [DayProgress]
    @Environment(\.modelContext) private var context

    @State private var showWeighIn = false
    @State private var showCoach = false
    @State private var showRefuel = false
    @State private var madeWeightKg: Double?

    private var snapshot: DailySnapshot {
        PlanCalculator.snapshot(athlete: athlete, plan: plan, weighIns: weighIns)
    }

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var dayProgress: DayProgress? {
        progressRows.first { $0.dayKey == todayKey }
    }

    private var latestWeighIn: WeighIn? { weighIns.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    heroCard
                    VerdictBanner(verdict: snapshot.verdict)
                    actionRow

                    if snapshot.emergencyStage > 0 {
                        emergencyCard
                    }

                    protocolCard
                    disclaimer
                }
                .padding(20)
                .padding(.bottom, 64)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showWeighIn) {
                WeighInSheet(athlete: athlete, plan: plan) { savedKg, made in
                    if made {
                        madeWeightKg = savedKg
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCoach) {
                CoachView(athlete: athlete, plan: plan)
            }
            .sheet(isPresented: $showRefuel) {
                NavigationStack { RefuelView(athlete: athlete, plan: plan) }
            }
            .fullScreenCover(item: Binding(
                get: { madeWeightKg.map { MadeWeightPayload(kg: $0) } },
                set: { if $0 == nil { madeWeightKg = nil } }
            )) { payload in
                MadeWeightView(athlete: athlete, plan: plan, weightKg: payload.kg)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                Text(athlete.name.isEmpty ? "Your cut" : athlete.name)
                    .font(.title3.bold())
            }
            Spacer()
            Text(snapshot.daysOut == 0 ? "WEIGH-IN DAY" : "\(snapshot.daysOut) DAYS OUT")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.card, in: Capsule())
                .foregroundStyle(Theme.muted)
                .padding(.trailing, 34)
        }
    }

    private var heroCard: some View {
        VStack(spacing: 18) {
            HStack {
                Text("TOMORROW'S TARGET")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Label("\(athlete.weightClassLabel) limit", systemImage: "flag.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(UnitConversion.string(snapshot.todayTargetKg, unit: athlete.unit, decimals: 1))
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(athlete.unit.label)
                            .font(.headline)
                            .foregroundStyle(Theme.muted)
                    }
                    Text(PlanCalculator.instruction(deltaKg: snapshot.deltaKg, unit: athlete.unit))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                ProgressRing(progress: snapshot.progress)
                    .frame(width: 96, height: 96)
            }

            HStack(spacing: 10) {
                statusChip(title: "Now", value: UnitConversion.string(snapshot.currentKg, unit: athlete.unit, decimals: 1))
                statusChip(title: "Tomorrow", value: UnitConversion.string(snapshot.tomorrowTargetKg, unit: athlete.unit, decimals: 1))
                statusChip(title: "Class", value: UnitConversion.string(plan.targetWeightKg, unit: athlete.unit, decimals: 1))
            }
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24))
    }

    private func statusChip(title: String, value: String) -> some View {
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

    private var emergencyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.heart.fill").foregroundStyle(Theme.danger)
                Text(SafetyEngine.stageTitle(snapshot.emergencyStage))
                    .font(.subheadline.weight(.bold))
            }
            Text(emergencyDetail)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            NavigationLink {
                EmergencyModeView(athlete: athlete, plan: plan, stage: snapshot.emergencyStage)
            } label: {
                Text("Open emergency mode")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.brand)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }

    private var emergencyDetail: String {
        switch snapshot.emergencyStage {
        case 3: return "The gap is over 5% of your body weight. We will not give you a cut protocol. Move up a class or postpone."
        case 2: return "Sauna rounds are allowed only in the final 48 hours with a 30-minute daily cap. Cooling between rounds is mandatory."
        default: return "Small water and sodium adjustments only. No extreme methods."
        }
    }

    private var protocolCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's protocol")
                    .font(.headline)
                Spacer()
                Text(snapshot.daysOut <= 7 ? "FIGHT WEEK" : "BUILD PHASE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.brand)
            }

            protocolRow(title: "Water", value: waterText, icon: "drop.fill", checked: dayProgress?.waterDone ?? false, tint: .blue) {
                toggle(\.waterDone)
            }
            protocolRow(title: "Sodium", value: "\(snapshot.targets.sodiumMG) mg", icon: "cube.fill", checked: dayProgress?.sodiumDone ?? false, tint: Theme.amber) {
                toggle(\.sodiumDone)
            }
            protocolRow(title: "Carbs", value: "\(snapshot.targets.carbsG) g", icon: "flame.fill", checked: dayProgress?.carbsDone ?? false, tint: .orange) {
                toggle(\.carbsDone)
            }
            protocolRow(title: "Fiber", value: "\(snapshot.targets.fiberG) g", icon: "leaf.fill", checked: dayProgress?.fiberDone ?? false, tint: .green) {
                toggle(\.fiberDone)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var waterText: String {
        if snapshot.targets.waterML == 0 { return "0" }
        return snapshot.targets.waterML >= 1000
            ? String(format: "%.1f L", Double(snapshot.targets.waterML) / 1000)
            : "\(snapshot.targets.waterML) ml"
    }

    private func protocolRow(title: String, value: String, icon: String, checked: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(value).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button(action: action) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(checked ? Theme.brand : Theme.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark \(title) complete")
        }
        .padding(.vertical, 4)
    }

    private func toggle(_ keyPath: ReferenceWritableKeyPath<DayProgress, Bool>) {
        let row: DayProgress
        if let existing = dayProgress {
            row = existing
        } else {
            row = DayProgress(dayKey: todayKey)
            context.insert(row)
        }
        row[keyPath: keyPath].toggle()
        try? context.save()
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            actionButton(title: "Weigh in", icon: "scalemass.fill", filled: true) {
                showWeighIn = true
            }
            actionButton(title: "Coach", icon: "brain.head.profile", filled: false) {
                showCoach = true
            }
            actionButton(title: "Refuel", icon: "bolt.heart.fill", filled: false) {
                showRefuel = true
            }
        }
    }

    private func actionButton(title: String, icon: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(filled ? Theme.brand : Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(filled ? .black : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var disclaimer: some View {
        Text("Not medical advice. Cutting weight carries real risks. Stop if you feel dizzy or confused.")
            .font(.caption2)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 { return "GOOD MORNING" }
        if hour < 17 { return "GOOD AFTERNOON" }
        return "GOOD EVENING"
    }
}

struct ProgressRing: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.02))
                .stroke(Theme.brand, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("completed")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .accessibilityLabel("Cut progress \(Int(progress * 100)) percent")
    }
}

struct MadeWeightPayload: Identifiable {
    var kg: Double
    var id: Double { kg }
}

struct WeighInSheet: View {
    @Bindable var athlete: Athlete
    @Bindable var plan: CutPlan
    @Query(sort: \WeighIn.date, order: .reverse) private var weighIns: [WeighIn]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var value = ""
    @State private var saved = false
    var onSaved: (Double, Bool) -> Void

    private var enteredKg: Double {
        UnitConversion.toKg(Double(value) ?? 0, unit: athlete.unit)
    }

    private var deltaText: String {
        guard enteredKg > 0 else { return "Enter this morning's weight." }
        let delta = enteredKg - plan.targetWeightKg
        if delta <= 0 { return "At or under the class limit." }
        return "\(UnitConversion.string(delta, unit: athlete.unit)) \(athlete.unit.label) over the limit."
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Morning weigh-in")
                    .font(.title.bold())
                Text("Log before food or water. First fasted weight of the day is the one we use.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("0.0", text: $value)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .frame(maxWidth: 180)
                    Text(athlete.unit.label)
                        .font(.headline)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                }
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))

                Text(deltaText)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)

                Button(action: save) {
                    Text(saved ? "Saved" : "Save weigh-in")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.black)
                }
                .disabled(enteredKg <= 0 || saved)

                Spacer()
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let cal = Calendar.current
        let sameDay = weighIns.contains { cal.isDate($0.date, inSameDayAs: Date()) }
        let madeWeight = enteredKg <= plan.targetWeightKg + 0.01
        let entry = WeighIn(weightKg: enteredKg, date: Date(), source: .manual, isReference: sameDay, isMadeWeight: madeWeight)
        context.insert(entry)
        plan.madeWeight = plan.madeWeight || madeWeight
        try? context.save()

        value = ""
        saved = true
        onSaved(enteredKg, madeWeight)

        Task {
            await HealthKitService.shared.save(weightKg: enteredKg)
        }

        let snapshot = PlanCalculator.snapshot(athlete: athlete, plan: plan, weighIns: [entry])
        WidgetSnapshotService.update(tomorrowTargetKg: snapshot.todayTargetKg, daysOut: snapshot.daysOut, unit: athlete.unit)
        NotificationService.shared.scheduleDailyReminder(tomorrowTargetKg: snapshot.todayTargetKg, unit: athlete.unit)

        dismiss()
    }
}
