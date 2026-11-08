import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let monthlyID = "com.zzoutuo.CutSzn.pro.monthly"
    static let yearlyID = "com.zzoutuo.CutSzn.pro.yearly"
    static let coachID = "com.zzoutuo.CutSzn.coach.yearly"
    static let lifetimeID = "com.zzoutuo.CutSzn.pro.byo.lifetime"
    static let passID = "com.zzoutuo.CutSzn.singlecut.pass"

    static let allIDs = [monthlyID, yearlyID, lifetimeID, passID, coachID]

    @Published var products: [Product] = []
    @Published var isPro = false
    @Published var isCoach = false
    @Published var isLoading = false
    @Published var loadError: String?

    private var listener: Task<Void, Never>?

    private init() {
        listener = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Self.allIDs)
                .sorted { rank($0.id) < rank($1.id) }
            loadError = nil
        } catch {
            loadError = "Purchases are unavailable right now. Try again in a moment."
        }
    }

    private func rank(_ id: String) -> Int {
        Self.allIDs.firstIndex(of: id) ?? 99
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    return true
                }
                loadError = "The purchase could not be verified."
                return false
            case .userCancelled:
                return false
            case .pending:
                loadError = "Purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            loadError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            loadError = "Restore failed: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var pro = false
        var coach = false

        for id in [Self.monthlyID, Self.yearlyID, Self.lifetimeID] {
            if let result = await Transaction.currentEntitlement(for: id),
               case .verified(let transaction) = result,
               transaction.revocationDate == nil {
                pro = true
            }
        }

        if let result = await Transaction.currentEntitlement(for: Self.coachID),
           case .verified(let transaction) = result,
           transaction.revocationDate == nil {
            coach = true
        }

        if let expiry = storedPassExpiry(), expiry > Date() {
            pro = true
        }

        isPro = pro
        isCoach = coach
    }

    func storePassPurchaseDate(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "pass.purchasedAt")
    }

    private func storedPassExpiry() -> Date? {
        let stamp = UserDefaults.standard.double(forKey: "pass.purchasedAt")
        guard stamp > 0 else { return nil }
        return Date(timeIntervalSince1970: stamp).addingTimeInterval(30 * 24 * 3600)
    }

    func product(_ id: String) -> Product? {
        products.first { $0.id == id }
    }

    func displayPrice(_ id: String) -> String {
        guard let product = product(id) else { return "$—" }
        return product.displayPrice
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    if transaction.productID == PurchaseManager.passID {
                        await MainActor.run {
                            self?.storePassPurchaseDate(transaction.purchaseDate)
                        }
                    }
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }

    deinit {
        listener?.cancel()
    }
}
