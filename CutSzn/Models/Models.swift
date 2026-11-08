import Foundation
import SwiftData
import SwiftUI

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var label: String { self == .male ? "Male" : "Female" }
}

enum Sport: String, Codable, CaseIterable, Identifiable {
    case ncaaWrestling, nfhsWrestling, bjj, mma, boxing
    var id: String { rawValue }

    var title: String {
        switch self {
        case .ncaaWrestling: return "NCAA Wrestling"
        case .nfhsWrestling: return "High School"
        case .bjj: return "BJJ"
        case .mma: return "MMA"
        case .boxing: return "Boxing"
        }
    }

    var shortTitle: String {
        switch self {
        case .ncaaWrestling: return "NCAA"
        case .nfhsWrestling: return "NFHS"
        case .bjj: return "BJJ"
        case .mma: return "MMA"
        case .boxing: return "Boxing"
        }
    }

    var orgID: String {
        switch self {
        case .ncaaWrestling: return "NCAA"
        case .nfhsWrestling: return "NFHS"
        case .bjj: return "IBJJF"
        case .mma: return "UWW"
        case .boxing: return "BOXING"
        }
    }

    var icon: String {
        switch self {
        case .ncaaWrestling: return "figure.wrestling"
        case .nfhsWrestling: return "graduationcap.fill"
        case .bjj: return "figure.martial.arts"
        case .mma: return "figure.boxing"
        case .boxing: return "figure.boxing"
        }
    }
}

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case lbs, kg
    var id: String { rawValue }
    var label: String { self == .lbs ? "lbs" : "kg" }
}

enum VerdictKind: String, Codable {
    case green, yellow, red
}

enum WeighInSource: String, Codable {
    case manual, healthKit
}

enum WeighInFormat: String, Codable {
    case dayBefore, hoursBefore
}

enum OrgRule: String, Codable {
    case ncaa = "NCAA"
    case nfhs = "NFHS"
    case ibjjf = "IBJJF"
    case uww = "UWW"
    case boxing = "BOXING"

    var usgLimit: Double {
        self == .ncaa ? 1.020 : 1.025
    }

    var weeklyLossCapPct: Double { 1.5 }

    var weighInFormat: WeighInFormat {
        switch self {
        case .nfhs, .uww, .boxing: return .dayBefore
        case .ncaa, .ibjjf: return .hoursBefore
        }
    }

    var displayName: String {
        switch self {
        case .ncaa: return "NCAA Wrestling"
        case .nfhs: return "NFHS High School"
        case .ibjjf: return "IBJJF"
        case .uww: return "UWW / Olympic"
        case .boxing: return "Boxing"
        }
    }
}

@Model
final class Athlete {
    var name: String = ""
    var sexRaw: String = Sex.male.rawValue
    var age: Int = 16
    var heightCm: Double = 170
    var sportRaw: String = Sport.nfhsWrestling.rawValue
    var weightClassLabel: String = "145"
    var targetWeightKg: Double = 65.771
    var walkWeightKg: Double = 0
    var unitRaw: String = WeightUnit.lbs.rawValue
    var onboarded: Bool = false
    var weighInDate: Date = Date()
    var createdAt: Date = Date()

    init(name: String = "", sex: Sex = .male, age: Int = 16, heightCm: Double = 170,
         sport: Sport = .nfhsWrestling, weightClassLabel: String = "145",
         targetWeightKg: Double = 65.771, walkWeightKg: Double = 0,
         unit: WeightUnit = .lbs, weighInDate: Date = Date()) {
        self.name = name
        self.sexRaw = sex.rawValue
        self.age = age
        self.heightCm = heightCm
        self.sportRaw = sport.rawValue
        self.weightClassLabel = weightClassLabel
        self.targetWeightKg = targetWeightKg
        self.walkWeightKg = walkWeightKg
        self.unitRaw = unit.rawValue
        self.weighInDate = weighInDate
        self.createdAt = Date()
    }

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var sport: Sport {
        get { Sport(rawValue: sportRaw) ?? .nfhsWrestling }
        set { sportRaw = newValue.rawValue }
    }

    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRaw) ?? .lbs }
        set { unitRaw = newValue.rawValue }
    }

    var org: OrgRule { sport.orgID == "BOXING" ? .boxing : OrgRule(rawValue: sport.orgID) ?? .nfhs }
}

@Model
final class CutPlan {
    var startWeightKg: Double = 0
    var targetWeightKg: Double = 0
    var weighInDate: Date = Date()
    var createdAt: Date = Date()
    var isActive: Bool = true
    var verdictRaw: String = VerdictKind.green.rawValue
    var orgRaw: String = OrgRule.nfhs.rawValue
    var emergencyStage: Int = 0
    var refuelStartedAt: Date? = nil
    var refuelCompletedSteps: String = ""
    var madeWeight: Bool = false

    init(startWeightKg: Double, targetWeightKg: Double, weighInDate: Date, org: OrgRule) {
        self.startWeightKg = startWeightKg
        self.targetWeightKg = targetWeightKg
        self.weighInDate = weighInDate
        self.orgRaw = org.rawValue
        self.createdAt = Date()
    }

    var org: OrgRule { OrgRule(rawValue: orgRaw) ?? .nfhs }
    var verdict: VerdictKind { VerdictKind(rawValue: verdictRaw) ?? .green }
}

@Model
final class WeighIn {
    var date: Date = Date()
    var weightKg: Double = 0
    var sourceRaw: String = WeighInSource.manual.rawValue
    var isReference: Bool = false
    var isMadeWeight: Bool = false

    init(weightKg: Double, date: Date = Date(), source: WeighInSource = .manual, isReference: Bool = false, isMadeWeight: Bool = false) {
        self.weightKg = weightKg
        self.date = date
        self.sourceRaw = source.rawValue
        self.isReference = isReference
        self.isMadeWeight = isMadeWeight
    }

    var source: WeighInSource { WeighInSource(rawValue: sourceRaw) ?? .manual }
}

@Model
final class USGLog {
    var date: Date = Date()
    var value: Double = 1.015

    init(value: Double, date: Date = Date()) {
        self.value = value
        self.date = date
    }
}

@Model
final class MealLog {
    var date: Date = Date()
    var name: String = ""
    var carbsG: Double = 0
    var sodiumMG: Double = 0
    var fiberG: Double = 0
    var kcal: Double = 0
    var verdict: String = "portion"

    init(name: String, carbsG: Double, sodiumMG: Double, fiberG: Double, kcal: Double, verdict: String, date: Date = Date()) {
        self.name = name
        self.carbsG = carbsG
        self.sodiumMG = sodiumMG
        self.fiberG = fiberG
        self.kcal = kcal
        self.verdict = verdict
        self.date = date
    }
}

@Model
final class DayProgress {
    var dayKey: String = ""
    var waterDone: Bool = false
    var sodiumDone: Bool = false
    var carbsDone: Bool = false
    var fiberDone: Bool = false
    var mealCarbsG: Double = 0
    var mealSodiumMG: Double = 0
    var mealFiberG: Double = 0

    init(dayKey: String) {
        self.dayKey = dayKey
    }
}
