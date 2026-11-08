import SwiftUI
import SwiftData

@main
struct CutSznApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Athlete.self, CutPlan.self, WeighIn.self, USGLog.self, MealLog.self, DayProgress.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            container = try! ModelContainer(
                for: Athlete.self, CutPlan.self, WeighIn.self, USGLog.self, MealLog.self, DayProgress.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        #if DEBUG
        if CommandLine.arguments.contains("-demoSeed") {
            DemoSeed.apply(container: container)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

#if DEBUG
enum DemoSeed {
    static func apply(container: ModelContainer) {
        let context = ModelContext(container)
        let existing = (try? context.fetch(FetchDescriptor<Athlete>())) ?? []
        guard existing.isEmpty else { return }

        let athlete = Athlete(name: "Jordan", sex: .male, age: 17, heightCm: 175,
                              sport: .nfhsWrestling, weightClassLabel: "145",
                              targetWeightKg: 65.771, walkWeightKg: 68.6, unit: .lbs,
                              weighInDate: Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date())
        athlete.onboarded = true
        context.insert(athlete)

        let plan = CutPlan(startWeightKg: 68.6, targetWeightKg: 65.771,
                           weighInDate: athlete.weighInDate, org: .nfhs)
        plan.createdAt = Calendar.current.date(byAdding: .day, value: -11, to: Date()) ?? Date()
        context.insert(plan)

        let weights: [Double] = [68.6, 68.4, 68.2, 68.0, 67.9, 67.8, 67.6, 67.5, 67.4, 67.35, 67.2]
        for (index, kg) in weights.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: index - (weights.count - 1), to: Date()) ?? Date()
            let entry = WeighIn(weightKg: kg, date: date, source: index % 2 == 0 ? .manual : .healthKit)
            context.insert(entry)
        }

        context.insert(USGLog(value: 1.014, date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()))
        context.insert(USGLog(value: 1.019, date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let progress = DayProgress(dayKey: formatter.string(from: Date()))
        progress.waterDone = true
        context.insert(progress)

        try? context.save()
    }

    static var tabIndex: Int {
        guard let index = CommandLine.arguments.firstIndex(of: "-demoTab"),
              CommandLine.arguments.count > index + 1,
              let value = Int(CommandLine.arguments[index + 1]) else { return 0 }
        return value
    }
}
#endif
