import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var purchases = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID = PurchaseManager.yearlyID
    @State private var working = false
    @State private var message: String?

    private let privacyURL = URL(string: "https://asunnyboy861.github.io/CutSzn/privacy.html")!
    private let termsURL = URL(string: "https://asunnyboy861.github.io/CutSzn/terms.html")!

    private var orderedProducts: [Product] {
        purchases.products
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    featureList
                    productList
                    subscribeArea
                    legalArea
                }
                .padding(20)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("CutSzn Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The weight cut your coach would write — if your coach did the math.")
                .font(.title3.bold())
            Text("Free forever core. Pro adds unlimited cuts, the cloud coach, meal scans, and the team dashboard.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            feature("Unlimited cut plans and full season archive")
            feature("30 cloud meal scans and 60 cloud coach replies each month")
            feature("Share your dashboard with a coach")
            feature("All widget themes")
            feature("Apple on-device AI stays unlimited for everyone")
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func feature(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.brand)
            Text(text)
                .font(.subheadline)
        }
    }

    private var productList: some View {
        VStack(spacing: 10) {
            ForEach(orderedProducts) { product in
                productRow(product)
            }
            if purchases.isLoading {
                ProgressView().padding()
            }
            if let error = purchases.loadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    private func productRow(_ product: Product) -> some View {
        let selected = selectedID == product.id
        return Button {
            selectedID = product.id
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Theme.brand : Theme.muted)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title(for: product))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if product.id == PurchaseManager.yearlyID {
                            Text("BEST VALUE")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Theme.brand.opacity(0.16), in: Capsule())
                                .foregroundStyle(Theme.brand)
                        }
                    }
                    Text(subtitle(for: product))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .padding(14)
            .background(selected ? Theme.brandDim : Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Theme.brand : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title(for: product)) \(product.displayPrice)")
    }

    private func title(for product: Product) -> String {
        switch product.id {
        case PurchaseManager.monthlyID: return "Pro Monthly"
        case PurchaseManager.yearlyID: return "Pro Yearly"
        case PurchaseManager.lifetimeID: return "Pro BYO Lifetime"
        case PurchaseManager.passID: return "Single-Cut Pass"
        case PurchaseManager.coachID: return "Coach Team Yearly"
        default: return product.displayName
        }
    }

    private func subtitle(for product: Product) -> String {
        switch product.id {
        case PurchaseManager.monthlyID: return "Auto-renewing · 1 month"
        case PurchaseManager.yearlyID: return "Auto-renewing · 1 year · 7-day free trial"
        case PurchaseManager.lifetimeID: return "One-time purchase · your own API key"
        case PurchaseManager.passID: return "30 days · does not auto-renew"
        case PurchaseManager.coachID: return "Auto-renewing · 1 year · up to 30 athletes"
        default: return product.description
        }
    }

    private var subscribeArea: some View {
        VStack(spacing: 10) {
            Button {
                purchaseSelected()
            } label: {
                HStack {
                    if working { ProgressView().tint(.black) }
                    Text(buttonTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.brand, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.black)
            }
            .disabled(working || selectedProduct == nil)

            Text(autoRenewText)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            Button("Restore Purchases") {
                Task {
                    working = true
                    await purchases.restore()
                    working = false
                    message = purchases.isPro ? "Purchases restored." : "No active purchases found."
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.brand)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var selectedProduct: Product? {
        purchases.products.first { $0.id == selectedID }
    }

    private var buttonTitle: String {
        guard let product = selectedProduct else { return "Continue" }
        if product.id == PurchaseManager.lifetimeID { return "Unlock for \(product.displayPrice)" }
        if product.id == PurchaseManager.passID { return "Buy pass for \(product.displayPrice)" }
        return "Start for \(product.displayPrice)"
    }

    private var autoRenewText: String {
        guard let product = selectedProduct else {
            return "Prices are loaded from the App Store."
        }
        switch product.id {
        case PurchaseManager.lifetimeID:
            return "One-time purchase. No recurring charges. Cloud AI quota is not included."
        case PurchaseManager.passID:
            return "One payment for 30 days of access. It does not renew automatically."
        default:
            return "Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage or cancel in your App Store account settings."
        }
    }

    private var legalArea: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: privacyURL)
                Link("Terms of Use", destination: termsURL)
            }
            .font(.caption2)
            .foregroundStyle(Theme.brand)

            Text("CutSzn is not medical advice. Cutting weight carries real risks.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func purchaseSelected() {
        guard let product = selectedProduct else { return }
        working = true
        Task {
            let success = await purchases.purchase(product)
            await MainActor.run {
                working = false
                if success {
                    if product.id == PurchaseManager.passID {
                        purchases.storePassPurchaseDate(Date())
                    }
                    message = "You're in. Enjoy the season."
                } else if let error = purchases.loadError {
                    message = error
                }
            }
        }
    }
}
