import Foundation

enum UnitConversion {
    static let kgPerLb = 0.45359237

    static func toKg(_ value: Double, unit: WeightUnit) -> Double {
        unit == .lbs ? value * kgPerLb : value
    }

    static func fromKg(_ kg: Double, unit: WeightUnit) -> Double {
        unit == .lbs ? kg / kgPerLb : kg
    }

    static func number(_ kg: Double, unit: WeightUnit) -> Double {
        fromKg(kg, unit: unit)
    }

    static func string(_ kg: Double, unit: WeightUnit, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", fromKg(kg, unit: unit))
    }

    static func wholeString(_ kg: Double, unit: WeightUnit) -> String {
        String(format: "%.0f", fromKg(kg, unit: unit))
    }
}

struct ProtocolTargets: Equatable {
    var waterML: Int = 0
    var sodiumMG: Int = 0
    var carbsG: Int = 0
    var fiberG: Int = 0
}

struct DayTarget: Identifiable {
    var date: Date
    var targetKg: Double
    var isFightWeek: Bool
    var id: Date { date }

    var targetDisplay: String { String(format: "%.1f", targetKg) }
}

struct CutVerdict {
    enum Kind { case green, yellow, red }
    var kind: Kind
    var rules: [String] = []
    var reason: String = ""

    var title: String {
        switch kind {
        case .green: return "You're on the glide path"
        case .yellow: return "Aggressive but possible"
        case .red: return "This cut is above the safety limit"
        }
    }

    var bannerText: String {
        switch kind {
        case .green: return "GREEN — SAFE TO FOLLOW"
        case .yellow: return "YELLOW — HARD RULES APPLY"
        case .red: return "RED — DO NOT START THIS CUT"
        }
    }
}

enum CutPlanEngine {
    static func bmr(weightKg: Double, heightCm: Double, age: Int, sex: Sex) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    static func daysOut(weighInDate: Date, now: Date = Date()) -> Int {
        let cal = Calendar.current
        let from = cal.startOfDay(for: now)
        let to = cal.startOfDay(for: weighInDate)
        return max(cal.dateComponents([.day], from: from, to: to).day ?? 0, 0)
    }

    static func verdict(currentKg: Double, targetKg: Double, days: Int, org: OrgRule) -> CutVerdict {
        guard currentKg > 0 else {
            return CutVerdict(kind: .green)
        }
        let totalCutPct = (currentKg - targetKg) / currentKg * 100
        let acuteCap = 5.0
        let weeklyCap = org.weeklyLossCapPct
        let weeks = max(Double(days) / 7.0, 0.4)
        let safeCutPct = weeklyCap * weeks

        if totalCutPct > acuteCap {
            return CutVerdict(kind: .red, reason: String(
                format: "This cut is %.1f%% of your body weight — above the 5%% safety limit. Move up a class or postpone the weigh-in.", totalCutPct))
        }
        if totalCutPct > safeCutPct {
            return CutVerdict(kind: .yellow, rules: [
                "Water load strictly on protocol — no skipping days",
                "USG check every morning: \(org.displayName) limit \(String(format: "%.3f", org.usgLimit))",
                "Sauna only in the final 48 hours, 30 minutes maximum per day",
                "No second-week emergency cuts on top of this plan"
            ])
        }
        return CutVerdict(kind: .green)
    }

    static func glidePath(currentKg: Double, targetKg: Double, weighInDate: Date, now: Date = Date()) -> [DayTarget] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let end = cal.startOfDay(for: weighInDate)
        let days = max(cal.dateComponents([.day], from: start, to: end).day ?? 0, 0)
        let totalDrop = max(currentKg - targetKg, 0)

        guard days > 0 else {
            return [DayTarget(date: end, targetKg: targetKg, isFightWeek: true)]
        }

        var path: [DayTarget] = []
        for day in 0...days {
            let date = cal.date(byAdding: .day, value: day, to: start) ?? start
            let fraction: Double
            if days <= 7 {
                fraction = Double(day) / Double(days)
            } else {
                let fatDays = days - 7
                if day <= fatDays {
                    fraction = 0.55 * Double(day) / Double(max(fatDays, 1))
                } else {
                    fraction = 0.55 + 0.45 * Double(day - fatDays) / 7.0
                }
            }
            let weight = currentKg - totalDrop * fraction
            path.append(DayTarget(date: date, targetKg: weight, isFightWeek: days - day <= 7))
        }
        return path
    }
}

enum ProtocolCurve {
    static func targets(daysUntilWeighIn days: Int, weightKg: Double) -> ProtocolTargets {
        switch days {
        case 7...:
            return ProtocolTargets(waterML: Int(weightKg * 100), sodiumMG: 5000, carbsG: 250, fiberG: 30)
        case 4...6:
            let water = [3500, 2500, 2000][min(max(6 - days, 0), 2)]
            return ProtocolTargets(waterML: water, sodiumMG: 1500, carbsG: 250, fiberG: 30)
        case 2...3:
            return ProtocolTargets(waterML: 1500, sodiumMG: 0, carbsG: 80, fiberG: 12)
        case 1:
            return ProtocolTargets(waterML: 400, sodiumMG: 0, carbsG: 50, fiberG: 10)
        default:
            return ProtocolTargets(waterML: 0, sodiumMG: 0, carbsG: 0, fiberG: 0)
        }
    }
}

struct RefuelStep: Identifiable {
    var id: Int { hourOffset }
    var hourOffset: Int
    var title: String
    var detail: String
    var fluidML: Double?
    var carbsG: Double?
}

enum RefuelEngine {
    static func build(fluidLostKg: Double, weighInFormat: WeighInFormat) -> [RefuelStep] {
        let lost = max(fluidLostKg, 0)
        let fluidML = lost * 1500
        var steps: [RefuelStep] = [
            RefuelStep(hourOffset: 0, title: "First 60 minutes",
                       detail: "Sip 500–750 ml of an electrolyte drink. Small, frequent mouthfuls.",
                       fluidML: 700, carbsG: lost * 25),
            RefuelStep(hourOffset: 1, title: "Keep loading",
                       detail: "Sodium fluids absorb 25–35% better than plain water.",
                       fluidML: fluidML * 0.2, carbsG: lost * 30),
            RefuelStep(hourOffset: 4, title: "Real food + salt",
                       detail: "Rice, pasta, salted potatoes. Keep fiber low today.",
                       fluidML: fluidML * 0.2, carbsG: lost * 35),
            RefuelStep(hourOffset: 8, title: "Carb top-up",
                       detail: "Target 7–10 g of carbs per kg of fluid lost, total.",
                       fluidML: fluidML * 0.15, carbsG: lost * 30),
            RefuelStep(hourOffset: 12, title: "Sleep prep",
                       detail: "Final 300–500 ml of sodium fluid. You should wake lighter.",
                       fluidML: 400, carbsG: nil),
            RefuelStep(hourOffset: 24, title: "Weigh-in check",
                       detail: "Goal: back within 2–3% of your walking weight.",
                       fluidML: nil, carbsG: nil)
        ]
        if weighInFormat == .dayBefore {
            steps.append(RefuelStep(hourOffset: 36, title: "Game-day breakfast",
                                    detail: "High carb, familiar foods only. Nothing new on game day.",
                                    fluidML: 500, carbsG: lost * 20))
            steps.append(RefuelStep(hourOffset: 44, title: "Final load",
                                    detail: "Stop large fluids 2 hours before you compete. Small sips after.",
                                    fluidML: 300, carbsG: lost * 15))
        }
        return steps
    }
}

enum SafetyEngine {
    static func stage(gapPct: Double) -> Int {
        if gapPct > 5 { return 3 }
        if gapPct > 2 { return 2 }
        return 1
    }

    static func stageTitle(_ stage: Int) -> String {
        switch stage {
        case 3: return "Stage 3 — We will not plan this cut"
        case 2: return "Stage 2 — Sauna rounds only"
        default: return "Stage 1 — Micro-adjust mode"
        }
    }

    static func usgPassed(_ value: Double, org: OrgRule) -> Bool {
        value <= org.usgLimit
    }

    static func usgCritical(_ value: Double) -> Bool {
        value > 1.030
    }
}

struct DailySnapshot {
    var currentKg: Double
    var todayTargetKg: Double
    var tomorrowTargetKg: Double
    var daysOut: Int
    var verdict: CutVerdict
    var targets: ProtocolTargets
    var emergencyStage: Int
    var progress: Double
    var deltaKg: Double
}

enum PlanCalculator {
    static func effectiveWeight(plan: CutPlan, weighIns: [WeighIn]) -> Double {
        let cal = Calendar.current
        let sorted = weighIns.sorted { $0.date < $1.date }
        guard let latestDay = sorted.last.map({ cal.startOfDay(for: $0.date) }) else {
            return plan.startWeightKg
        }
        let sameDay = sorted.filter { cal.isDate($0.date, inSameDayAs: latestDay) }
        return sameDay.first?.weightKg ?? plan.startWeightKg
    }

    static func snapshot(athlete: Athlete, plan: CutPlan, weighIns: [WeighIn], now: Date = Date()) -> DailySnapshot {
        let current = effectiveWeight(plan: plan, weighIns: weighIns)
        let days = CutPlanEngine.daysOut(weighInDate: plan.weighInDate, now: now)
        let path = CutPlanEngine.glidePath(currentKg: current, targetKg: plan.targetWeightKg, weighInDate: plan.weighInDate, now: now)
        let todayTarget = path.count > 1 ? path[1].targetKg : plan.targetWeightKg
        let tomorrowTarget = path.count > 2 ? path[2].targetKg : plan.targetWeightKg
        let targets = ProtocolCurve.targets(daysUntilWeighIn: days, weightKg: current)
        let gapPct = (current - plan.targetWeightKg) / current * 100
        let stage = days <= 2 ? SafetyEngine.stage(gapPct: gapPct) : 0
        let verdict = CutPlanEngine.verdict(currentKg: current, targetKg: plan.targetWeightKg, days: days, org: plan.org)
        let denom = max(plan.startWeightKg - plan.targetWeightKg, 0.1)
        let progress = min(max((plan.startWeightKg - current) / denom, 0), 1)
        return DailySnapshot(currentKg: current, todayTargetKg: todayTarget, tomorrowTargetKg: tomorrowTarget,
                             daysOut: days, verdict: verdict, targets: targets, emergencyStage: stage,
                             progress: progress, deltaKg: current - todayTarget)
    }

    static func instruction(deltaKg: Double, unit: WeightUnit) -> String {
        let delta = UnitConversion.number(abs(deltaKg), unit: unit)
        if delta < 0.1 {
            return "You are right on today's number. Hold tonight's protocol."
        }
        if deltaKg < 0 {
            return String(format: "You are %.1f %@ ahead. Eat and drink normally today.", delta, unit.label)
        }
        return String(format: "You are %.1f %@ over. Add the water on your protocol card and skip the salt.", delta, unit.label)
    }
}
