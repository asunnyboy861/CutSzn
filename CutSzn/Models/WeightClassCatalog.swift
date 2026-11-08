import Foundation

struct WeightClass: Codable, Identifiable, Hashable {
    var label: String
    var kg: Double
    var id: String { label }
}

struct OrgCatalog: Codable, Identifiable {
    var org: String
    var displayName: String
    var usgLimit: Double
    var weeklyCapPct: Double
    var weighInFormat: String
    var men: [WeightClass]
    var women: [WeightClass]
    var id: String { org }

    func classes(for sex: Sex) -> [WeightClass] {
        sex == .male ? men : women
    }
}

struct WeightClassFile: Codable {
    var orgs: [OrgCatalog]
}

enum WeightClassCatalog {
    static let all: [OrgCatalog] = load()
    static let fallback: [OrgCatalog] = [
        OrgCatalog(org: "NFHS", displayName: "NFHS High School", usgLimit: 1.025, weeklyCapPct: 1.5,
                   weighInFormat: "dayBefore",
                   men: [WeightClass(label: "145", kg: 65.771), WeightClass(label: "152", kg: 68.946)],
                   women: [WeightClass(label: "145", kg: 65.771), WeightClass(label: "155", kg: 70.308)]),
        OrgCatalog(org: "NCAA", displayName: "NCAA Wrestling", usgLimit: 1.020, weeklyCapPct: 1.5,
                   weighInFormat: "hoursBefore",
                   men: [WeightClass(label: "157", kg: 71.214)],
                   women: [WeightClass(label: "145", kg: 65.771)]) 
    ]

    private static func load() -> [OrgCatalog] {
        guard let url = Bundle.main.url(forResource: "WeightClasses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(WeightClassFile.self, from: data) else {
            return []
        }
        return file.orgs
    }

    static func catalog(for sport: Sport) -> OrgCatalog? {
        let list = all.isEmpty ? fallback : all
        return list.first { $0.org == sport.orgID }
    }

    static func classes(for sport: Sport, sex: Sex) -> [WeightClass] {
        catalog(for: sport)?.classes(for: sex) ?? []
    }

    static func targetKg(for sport: Sport, sex: Sex, label: String) -> Double? {
        classes(for: sport, sex: sex).first { $0.label == label }?.kg
    }
}
