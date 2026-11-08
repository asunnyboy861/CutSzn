import SwiftUI
import SwiftData

struct TeamView: View {
    @Bindable var athlete: Athlete
    var plan: CutPlan?
    @Query(sort: \WeighIn.date, order: .reverse) private var weighIns: [WeighIn]
    @Query(sort: \USGLog.date, order: .reverse) private var usgLogs: [USGLog]

    @StateObject private var purchases = PurchaseManager.shared
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var working = false
    @State private var errorText: String?
    @State private var showPaywall = false

    private var snapshot: DailySnapshot? {
        guard let plan else { return nil }
        return PlanCalculator.snapshot(athlete: athlete, plan: plan, weighIns: weighIns)
    }

    private var canShare: Bool { purchases.isPro || purchases.isCoach }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !canShare {
                        upsellCard
                    } else {
                        rosterCard
                        complianceCard
                        shareCard
                    }
                    explanationCard
                }
                .padding(20)
                .padding(.bottom, 64)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Team")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShare) {
                if let shareURL {
                    ActivityView(items: [shareURL])
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var upsellCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.badge.gearshape.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.brand)
            Text("Let your coach watch the cut")
                .font(.title3.bold())
            Text("Share a read-only dashboard: glide status, traffic lights, and the USG compliance report. Coaches can follow up to 30 athletes.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button {
                showPaywall = true
            } label: {
                Text("See Coach and Pro plans")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.black)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24))
    }

    private var rosterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Roster")
                    .font(.headline)
                Spacer()
                Text(purchases.isCoach ? "1 / 30 athletes" : "1 / 1 athlete")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.brandDim).frame(width: 44, height: 44)
                    Text(String((athlete.name.isEmpty ? "You" : athlete.name).prefix(1)))
                        .font(.headline)
                        .foregroundStyle(Theme.brand)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(athlete.name.isEmpty ? "You" : athlete.name)
                        .font(.subheadline.weight(.semibold))
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                if let snapshot {
                    Text(statusBadge(snapshot))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Theme.verdictColor(snapshot.verdict.kind).opacity(0.15), in: Capsule())
                        .foregroundStyle(Theme.verdictColor(snapshot.verdict.kind))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var statusText: String {
        guard let snapshot else { return "No active cut" }
        return "\(UnitConversion.string(snapshot.currentKg, unit: athlete.unit, decimals: 1)) \(athlete.unit.label) · \(snapshot.daysOut) days out"
    }

    private func statusBadge(_ snapshot: DailySnapshot) -> String {
        switch snapshot.verdict.kind {
        case .green: return "ON TRACK"
        case .yellow: return "WATCH"
        case .red: return "STOP"
        }
    }

    private var complianceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("USG compliance report")
                .font(.headline)
            if let plan {
                Text("\(plan.org.displayName) limit \(String(format: "%.3f", plan.org.usgLimit))")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            if usgLogs.isEmpty {
                Text("No USG logs yet. Athletes log test strips each morning during fight week.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(usgLogs.prefix(3)) { log in
                    HStack {
                        Text(log.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Text(String(format: "%.3f", log.value))
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(log.value <= (plan?.org.usgLimit ?? 1.025) ? "PASS" : "FAIL")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(log.value <= (plan?.org.usgLimit ?? 1.025) ? Theme.brand : Theme.danger)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share with a coach")
                .font(.headline)
            Text("Creates a read-only iCloud link. The coach sees your status and USG report — never edits your data.")
                .font(.caption)
                .foregroundStyle(Theme.muted)

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
            }

            Button {
                createShare()
            } label: {
                HStack {
                    if working { ProgressView().tint(.black) }
                    Text(working ? "Creating link…" : "Create coach link")
                    Spacer()
                    Image(systemName: "person.badge.plus")
                }
                .font(.headline)
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Theme.brandDim, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(Theme.brand)
            }
            .disabled(working)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var explanationCard: some View {
        Text("Team sharing uses iCloud. If iCloud is unavailable, CutSzn keeps everything on this device and the rest of the app still works.")
            .font(.caption2)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
    }

    private func createShare() {
        working = true
        errorText = nil
        Task {
            let available = await CloudShareService.shared.accountAvailable()
            guard available else {
                await MainActor.run {
                    errorText = "Sign in to iCloud to create a coach link."
                    working = false
                }
                return
            }
            do {
                let status = snapshot.map { "\(UnitConversion.string($0.currentKg, unit: athlete.unit)) \(athlete.unit.label), \($0.daysOut) days out, \(statusBadge($0))" } ?? "No active cut"
                let usg = usgLogs.first.map { String(format: "%.3f", $0.value) } ?? "none"
                let url = try await CloudShareService.shared.makeTeamShare(
                    athleteName: athlete.name.isEmpty ? "Athlete" : athlete.name,
                    statusText: status,
                    usgText: usg
                )
                await MainActor.run {
                    shareURL = url
                    showShare = true
                    working = false
                }
            } catch {
                await MainActor.run {
                    errorText = "Could not create the link: \(error.localizedDescription)"
                    working = false
                }
            }
        }
    }
}
