import SwiftUI
import SwiftData

struct RefuelView: View {
    @Bindable var athlete: Athlete
    @Bindable var plan: CutPlan
    @Query(sort: \WeighIn.date, order: .reverse) private var weighIns: [WeighIn]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var latest: WeighIn? { weighIns.first }

    private var walkingWeightKg: Double {
        athlete.walkWeightKg > 0 ? athlete.walkWeightKg : plan.startWeightKg
    }

    private var fluidLostKg: Double {
        guard let latest else { return 0 }
        return max(walkingWeightKg - latest.weightKg, 0)
    }

    private var steps: [RefuelStep] {
        RefuelEngine.build(fluidLostKg: fluidLostKg, weighInFormat: plan.org.weighInFormat)
    }

    private var completed: Set<Int> {
        Set(plan.refuelCompletedSteps.split(separator: ",").compactMap { Int($0) })
    }

    private var elapsedHours: Double {
        guard let start = plan.refuelStartedAt else { return 0 }
        return Date().timeIntervalSince(start) / 3600
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                if fluidLostKg <= 0 {
                    emptyState
                } else {
                    ForEach(steps) { step in
                        stepRow(step)
                    }
                }
                disclaimer
            }
            .padding(20)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Refuel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            if plan.refuelStartedAt == nil {
                plan.refuelStartedAt = Date()
                try? context.save()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("48-hour refuel")
                .font(.title2.bold())
            Text("You lost \(UnitConversion.string(fluidLostKg, unit: athlete.unit, decimals: 1)) \(athlete.unit.label) on the scale. Replace 150% of it with sodium fluid and carbs.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            HStack {
                Label(String(format: "%.1f L fluid target", fluidLostKg * 1.5), systemImage: "drop.fill")
                Spacer()
                Label("\(String(format: "%.0f", fluidLostKg * 8)) g carbs", systemImage: "flame.fill")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.brand)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "scalemass")
                .font(.system(size: 36))
                .foregroundStyle(Theme.muted)
            Text("Log your weigh-in first")
                .font(.headline)
            Text("We need your walking weight and your weigh-in weight to build the refuel plan.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private func stepRow(_ step: RefuelStep) -> some View {
        let done = completed.contains(step.hourOffset)
        return HStack(alignment: .top, spacing: 12) {
            Button {
                toggle(step)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(done ? Theme.brand : Theme.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark \(step.title) complete")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(step.title).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(hourLabel(step.hourOffset)).font(.caption2).foregroundStyle(Theme.muted)
                }
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                if let fluid = step.fluidML, let carbs = step.carbsG {
                    Text("\(Int(fluid)) ml · \(Int(carbs)) g carbs")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.brand)
                } else if let fluid = step.fluidML {
                    Text("\(Int(fluid)) ml")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.brand)
                }
            }
        }
        .padding(14)
        .background(done ? Theme.brand.opacity(0.08) : Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func hourLabel(_ offset: Int) -> String {
        let delta = Double(offset) - elapsedHours
        if delta > 0 { return String(format: "+%.0fh", delta) }
        return "now"
    }

    private func toggle(_ step: RefuelStep) {
        var set = completed
        if set.contains(step.hourOffset) {
            set.remove(step.hourOffset)
        } else {
            set.insert(step.hourOffset)
        }
        plan.refuelCompletedSteps = set.sorted().map(String.init).joined(separator: ",")
        try? context.save()
    }

    private var disclaimer: some View {
        Text("Not medical advice. Rehydrate with sodium and carbs together — plain water alone dilutes your sodium.")
            .font(.caption2)
            .foregroundStyle(Theme.muted)
    }
}
