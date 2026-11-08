import Foundation
import Security

#if canImport(FoundationModels)
import FoundationModels
#endif

enum KeychainHelper {
    static func save(_ data: Data, service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func saveString(_ value: String, service: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        save(data, service: service, account: account)
    }

    static func readString(service: String, account: String) -> String? {
        guard let data = read(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum AIProvider: String, CaseIterable, Identifiable {
    case openai, gemini, claude, deepseek, glm, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .claude: return "Anthropic Claude"
        case .deepseek: return "DeepSeek"
        case .glm: return "GLM / Z.ai"
        case .custom: return "Custom endpoint"
        }
    }

    var baseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .claude: return "https://api.anthropic.com/v1"
        case .deepseek: return "https://api.deepseek.com/v1"
        case .glm: return "https://api.z.ai/api/paas/v4"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .gemini: return "gemini-2.0-flash"
        case .claude: return "claude-3-5-haiku-latest"
        case .deepseek: return "deepseek-chat"
        case .glm: return "glm-4.6v-flash"
        case .custom: return ""
        }
    }

    var visionCapable: Bool {
        switch self {
        case .openai, .gemini, .claude, .glm: return true
        case .deepseek, .custom: return false
        }
    }

    var keyHint: String {
        switch self {
        case .openai: return "sk-…"
        case .gemini: return "AIza…"
        case .claude: return "sk-ant-…"
        case .deepseek: return "sk-…"
        case .glm: return "Your Z.ai key"
        case .custom: return "Your provider key"
        }
    }
}

struct BYOSettings: Codable {
    var providerRaw: String = AIProvider.openai.rawValue
    var baseURL: String = AIProvider.openai.baseURL
    var model: String = AIProvider.openai.defaultModel
    var supportsVision: Bool = true

    var provider: AIProvider {
        get { AIProvider(rawValue: providerRaw) ?? .custom }
        set { providerRaw = newValue.rawValue }
    }
}

enum AISettingsStore {
    static let service = "com.zzoutuo.CutSzn.ai"
    static let account = "apiKey"
    static let settingsKey = "ai.byo.settings"

    static var settings: BYOSettings {
        get {
            guard let data = UserDefaults.standard.data(forKey: settingsKey),
                  let decoded = try? JSONDecoder().decode(BYOSettings.self, from: data) else {
                return BYOSettings()
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: settingsKey)
            }
        }
    }

    static var apiKey: String? {
        get { KeychainHelper.readString(service: service, account: account) }
        set {
            if let value = newValue, !value.isEmpty {
                KeychainHelper.saveString(value, service: service, account: account)
            } else {
                KeychainHelper.delete(service: service, account: account)
            }
        }
    }

    static var hasKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    static var isReady: Bool {
        hasKey && !settings.baseURL.isEmpty && !settings.model.isEmpty
    }

    static func clearKey() {
        apiKey = nil
    }
}

enum AppleIntelligenceService {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    static func answer(prompt: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession()
            do {
                let response = try await session.respond(to: prompt)
                return response.content
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

struct AIMealItem: Codable, Identifiable {
    var name: String
    var carbsG: Double
    var sodiumMG: Double
    var fiberG: Double
    var kcal: Double
    var id: String { name }
}

struct MealAnalysis: Codable {
    var items: [AIMealItem]
    var verdict: String
    var note: String?

    var totalCarbs: Double { items.reduce(0) { $0 + $1.carbsG } }
    var totalSodium: Double { items.reduce(0) { $0 + $1.sodiumMG } }
    var totalFiber: Double { items.reduce(0) { $0 + $1.fiberG } }
    var totalKcal: Double { items.reduce(0) { $0 + $1.kcal } }
}

struct AIContext {
    var currentKg: Double
    var targetKg: Double
    var daysOut: Int
    var waterML: Int
    var sodiumMG: Int
    var carbsG: Int
    var fiberG: Int
    var unit: WeightUnit

    var prompt: String {
        """
        Athlete context: current weight \(UnitConversion.string(currentKg, unit: unit)) \(unit.label), \
        class limit \(UnitConversion.string(targetKg, unit: unit)) \(unit.label), \(daysOut) days to weigh-in. \
        Today's protocol: water \(waterML) ml, sodium \(sodiumMG) mg, carbs \(carbsG) g, fiber \(fiberG) g. \
        You are a combat-sport weigh-in coach. Be direct, specific, and safe. Never suggest a cut above 5% body weight, \
        never suggest sauna beyond 45 minutes a day, and always refuse unsafe requests.
        """
    }
}

struct AIResult {
    var text: String
    var sourceLabel: String
}

enum AIRouter {
    static func answer(question: String, context: AIContext, isPro: Bool) async -> AIResult {
        let prompt = "\(context.prompt)\n\nQuestion: \(question)"

        if AppleIntelligenceService.isAvailable {
            if let text = await AppleIntelligenceService.answer(prompt: prompt), !text.isEmpty {
                return AIResult(text: text, sourceLabel: "Apple Intelligence · on-device")
            }
        }

        if AISettingsStore.isReady {
            if let text = try? await OpenAICompatClient(settings: AISettingsStore.settings, key: AISettingsStore.apiKey ?? "").chat(prompt: prompt),
               !text.isEmpty {
                return AIResult(text: text, sourceLabel: "Your API key")
            }
        }

        if isPro, AIQuota.canCoach(isPro: isPro), let text = await CloudAI.chat(prompt: prompt), !text.isEmpty {
            AIQuota.incrementCoach()
            return AIResult(text: text, sourceLabel: "CutSzn Cloud")
        }

        return AIResult(text: LocalCoach.answer(question: question, context: context), sourceLabel: "Offline coach")
    }

    static func analyzeMeal(imageData: Data, context: AIContext, isPro: Bool) async -> (MealAnalysis?, String) {
        let prompt = """
        \(context.prompt)
        Identify every food item in this photo. Return strict JSON only:
        {"items":[{"name":"","carbsG":0,"sodiumMG":0,"fiberG":0,"kcal":0}],"verdict":"eat|avoid|portion","note":""}
        """

        if AISettingsStore.isReady && AISettingsStore.settings.supportsVision {
            let client = OpenAICompatClient(settings: AISettingsStore.settings, key: AISettingsStore.apiKey ?? "")
            if let text = try? await client.vision(prompt: prompt, imageData: imageData),
               let analysis = decodeAnalysis(text) {
                return (analysis, "Your API key")
            }
        }

        if isPro, AIQuota.canScan(isPro: isPro), let text = await CloudAI.vision(prompt: prompt, imageData: imageData),
           let analysis = decodeAnalysis(text) {
            AIQuota.incrementScan()
            return (analysis, "CutSzn Cloud")
        }

        return (nil, "Meal scanning needs Apple Intelligence, your own API key, or a Pro cloud quota.")
    }

    static func decodeAnalysis(_ text: String) -> MealAnalysis? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return nil }
        let json = String(text[start...end])
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MealAnalysis.self, from: data)
    }
}

struct OpenAICompatClient {
    var settings: BYOSettings
    var key: String

    func chat(prompt: String) async throws -> String {
        try await request(messages: [["role": "user", "content": prompt]])
    }

    func vision(prompt: String, imageData: Data) async throws -> String {
        let base64 = imageData.base64EncodedString()
        let content: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
        ]
        return try await request(messages: [["role": "user", "content": content]])
    }

    private func request(messages: [[String: Any]]) async throws -> String {
        guard let url = URL(string: settings.baseURL.hasSuffix("/chat/completions") ? settings.baseURL : settings.baseURL + "/chat/completions") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": settings.model,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 900
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }
}

enum CloudAI {
    struct Config {
        var key: String
        var endpoint: String
        var model: String
    }

    static var config: Config? {
        guard let url = Bundle.main.url(forResource: "GLMProxySecret", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let line = text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") }
        guard let line else { return nil }
        let parts = line.split(separator: "|").map(String.init)
        guard parts.count >= 3 else { return nil }
        return Config(key: parts[0], endpoint: parts[1], model: parts[2])
    }

    static func chat(prompt: String) async -> String? {
        guard let config else { return nil }
        let settings = BYOSettings(providerRaw: AIProvider.custom.rawValue, baseURL: config.endpoint, model: config.model, supportsVision: true)
        return try? await OpenAICompatClient(settings: settings, key: config.key).chat(prompt: prompt)
    }

    static func vision(prompt: String, imageData: Data) async -> String? {
        guard let config else { return nil }
        let settings = BYOSettings(providerRaw: AIProvider.custom.rawValue, baseURL: config.endpoint, model: config.model, supportsVision: true)
        return try? await OpenAICompatClient(settings: settings, key: config.key).vision(prompt: prompt, imageData: imageData)
    }
}

enum LocalCoach {
    static func answer(question: String, context: AIContext) -> String {
        let text = question.lowercased()
        let delta = context.currentKg - context.targetKg

        if text.contains("eat") {
            if context.carbsG < 100 {
                return "Not unless it is under 20 g of carbs and has no added salt. You are on a \(context.carbsG) g carb day. Save the meal for after weigh-in."
            }
            return "Yes if it fits today's macros: \(context.carbsG) g carbs, \(context.sodiumMG) mg sodium. Keep the portion palm-sized and skip salty sauces."
        }
        if text.contains("water") || text.contains("drink") {
            return "Today's water target is \(context.waterML) ml. Spread it across the day, sip — do not chug, and stop large fluids 2 hours before bed."
        }
        if text.contains("sodium") || text.contains("salt") {
            if context.sodiumMG == 0 {
                return "Sodium is at zero today. No added salt, no sports drinks, no processed food. Read every label."
            }
            return "Your sodium ceiling today is \(context.sodiumMG) mg. That is about \(String(format: "%.1f", Double(context.sodiumMG) / 1000)) teaspoons of salt across all food."
        }
        if text.contains("sauna") || text.contains("sweat") {
            return "Sauna only in the final 48 hours, 10–15 minutes per round with a full cooldown, and never more than 30–45 minutes in a day. If you feel dizzy, stop immediately."
        }
        if text.contains("over") || text.contains("behind") || text.contains("kg") || text.contains("lbs") || text.contains("pound") {
            return String(format: "You are %.1f %@ above the class limit. Do not panic-cut. Follow today's water (%d ml), keep sodium at %d mg, and log again tomorrow morning. If the gap is still over 5%% of your body weight, we will not plan a cut — move up a class.",
                          UnitConversion.number(abs(delta), unit: context.unit), context.unit.label,
                          context.waterML, context.sodiumMG)
        }
        return "Stay on today's protocol: \(context.waterML) ml water, \(context.sodiumMG) mg sodium, \(context.carbsG) g carbs, \(context.fiberG) g fiber. Log your morning weight before you eat. That is the whole job today."
    }
}
