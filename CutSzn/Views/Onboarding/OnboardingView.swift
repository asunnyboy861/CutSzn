import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Query private var athletes: [Athlete]

    @State private var step = 0
    @State private var sport: Sport = .nfhsWrestling
    @State private var sex: Sex = .male
    @State private var classLabel: String = ""
    @State private var weightText = "155"
    @State private var heightText = "178"
    @State private var ageText = "16"
    @State private var weighInDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var understood = false
    @State private var importing = false

    private var classes: [WeightClass] { WeightClassCatalog.classes(for: sport, sex: sex) }

    private var currentKg: Double { UnitConversion.toKg(Double(weightText) ?? 0, unit: .lbs) }
    private var targetKg: Double {
        WeightClassCatalog.targetKg(for: sport, sex: sex, label: classLabel) ?? currentKg
    }
    private var verdict: CutVerdict {
        CutPlanEngine.verdict(currentKg: currentKg, targetKg: targetKg,
                              days: CutPlanEngine.daysOut(weighInDate: weighInDate), org: orgRule)
    }
    private var orgRule: OrgRule {
        OrgRule(rawValue: sport.orgID) ?? .nfhs
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch step {
                        case 0: sportStep
                        case 1: statsStep
                        case 2: dateStep
                        default: verdictStep
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                footer
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(step == 0 ? "Welcome to CutSzn" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { withAnimation { step -= 1 } }
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .onAppear {
            if classLabel.isEmpty { classLabel = classes.first?.label ?? "" }
        }
        .onChange(of: sport) { _, _ in
            classLabel = classes.first?.label ?? ""
        }
        .onChange(of: sex) { _, _ in
            classLabel = classes.first?.label ?? ""
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Theme.brand : Color(uiColor: .tertiarySystemFill))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var sportStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What are you cutting for?")
                .font(.largeTitle.bold())
            Text("Pick your rule set. We use its weigh-in format and USG limit for every safety check.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Sport.allCases) { item in
                    Button {
                        sport = item
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 26))
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .background(sport == item ? Theme.brandDim : Theme.card, in: RoundedRectangle(cornerRadius: 18))
                        .overgroundBorder(sport == item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                }
            }

            Picker("Sex", selection: $sex) {
                ForEach(Sex.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Text("Weight class (lbs)")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(classes) { item in
                    Button {
                        classLabel = item.label
                    } label: {
                        Text(item.label)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(classLabel == item.label ? Theme.brandDim : Theme.card, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Weight class \(item.label) pounds")
                }
            }

            Text("\(orgRule.displayName) · USG limit \(String(format: "%.3f", orgRule.usgLimit)) · weekly loss cap \(String(format: "%.1f", orgRule.weeklyLossCapPct))%")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var statsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your baseline")
                .font(.largeTitle.bold())
            Text("We keep every weight in kilograms internally and show pounds. Nothing leaves your device.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

            VStack(spacing: 0) {
                numberRow(title: "Current weight", text: $weightText, suffix: "lbs", keyboard: .decimalPad)
                Divider()
                numberRow(title: "Height", text: $heightText, suffix: "cm", keyboard: .numberPad)
                Divider()
                numberRow(title: "Age", text: $ageText, suffix: "years", keyboard: .numberPad)
            }
            .padding(.horizontal, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))

            Button {
                importFromHealth()
            } label: {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                    Text(importing ? "Reading Health…" : "Import weight from Apple Health")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(importing)
            .accessibilityLabel("Import weight from Apple Health")

            Text("Close your eyes for a second — this is not medical advice. Cutting weight carries real risks.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }

    private func numberRow(title: String, text: Binding<String>, suffix: String, keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            TextField("0", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(suffix).font(.caption).foregroundStyle(Theme.muted).frame(width: 52, alignment: .leading)
        }
        .padding(.vertical, 14)
    }

    private var dateStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("When do you weigh in?")
                .font(.largeTitle.bold())
            Text("The glide path ends exactly on this date. You can change it later in Plan.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

            DatePicker("Weigh-in date", selection: $weighInDate, in: Date()...Date().addingTimeInterval(180 * 86400), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))

            let days = CutPlanEngine.daysOut(weighInDate: weighInDate)
            HStack {
                Text("\(days) days out").font(.headline)
                Spacer()
                Text("\(classLabel) lbs limit").font(.subheadline).foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var verdictStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Safety check")
                .font(.largeTitle.bold())
            Text("This is the gate. If the cut is unsafe, we will not build it.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

            VerdictBanner(verdict: verdict)

            if verdict.kind == .yellow {
                Toggle(isOn: $understood) {
                    Text("I will follow the hard rules exactly, including USG checks.")
                        .font(.subheadline)
                }
                .tint(Theme.brand)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Not medical advice", systemImage: "cross.case.fill")
                    .font(.footnote.weight(.semibold))
                Text("CutSzn provides training guidance, not medical care. Serious dehydration can be fatal. If you feel dizzy, confused, or stop sweating, stop and get help.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

            if verdict.kind == .red {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What we suggest instead").font(.headline)
                    Text("1. Move up one weight class for this event.")
                    Text("2. Push the weigh-in back by at least a week.")
                    Text("3. Talk to your coach or athletic trainer.")
                }
                .font(.subheadline)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case 0: return !classLabel.isEmpty
        case 1: return (Double(weightText) ?? 0) > 0 && (Double(heightText) ?? 0) > 0 && (Int(ageText) ?? 0) > 10
        case 2: return true
        default:
            if verdict.kind == .green { return true }
            if verdict.kind == .yellow { return understood }
            return false
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                if step == 3 {
                    finish()
                } else {
                    withAnimation { step += 1 }
                }
            } label: {
                Text(step == 3 ? "Start tracking" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canContinue ? Theme.brand : Color(uiColor: .tertiarySystemFill),
                                in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(canContinue ? .black : .secondary)
            }
            .disabled(!canContinue)
            .accessibilityLabel(step == 3 ? "Start tracking" : "Continue")

            if step == 3 && verdict.kind == .red {
                Text("The start button stays disabled for red cuts.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private func importFromHealth() {
        importing = true
        Task {
            _ = await HealthKitService.shared.requestAuthorization()
            if let kg = await HealthKitService.shared.latestWeightKg() {
                await MainActor.run {
                    weightText = String(format: "%.1f", UnitConversion.fromKg(kg, unit: .lbs))
                    importing = false
                }
            } else {
                await MainActor.run { importing = false }
            }
        }
    }

    private func finish() {
        let athlete = athletes.first ?? Athlete()
        if athletes.isEmpty { context.insert(athlete) }

        let height = Double(heightText) ?? 170
        let age = Int(ageText) ?? 16
        athlete.sex = sex
        athlete.age = age
        athlete.heightCm = height
        athlete.sport = sport
        athlete.weightClassLabel = classLabel
        athlete.targetWeightKg = targetKg
        athlete.walkWeightKg = currentKg
        athlete.unit = .lbs
        athlete.weighInDate = weighInDate
        athlete.onboarded = true

        let plan = CutPlan(startWeightKg: currentKg, targetWeightKg: targetKg, weighInDate: weighInDate, org: orgRule)
        plan.verdictRaw = verdict.kind == .green ? VerdictKind.green.rawValue : VerdictKind.yellow.rawValue
        context.insert(plan)

        try? context.save()

        Task {
            _ = await NotificationService.shared.requestAuthorization()
            NotificationService.shared.scheduleDailyReminder(tomorrowTargetKg: targetKg, unit: .lbs)
        }
        WidgetSnapshotService.update(tomorrowTargetKg: targetKg, daysOut: CutPlanEngine.daysOut(weighInDate: weighInDate), unit: .lbs)
    }
}

private extension View {
    func overgroundBorder(_ active: Bool) -> some View {
        overlay(RoundedRectangle(cornerRadius: 18).stroke(active ? Theme.brand : Color.clear, lineWidth: 1.5))
    }
}
