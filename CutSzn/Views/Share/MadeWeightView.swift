import SwiftUI

struct MadeWeightView: View {
    @Bindable var athlete: Athlete
    @Bindable var plan: CutPlan
    var weightKg: Double

    @Environment(\.dismiss) private var dismiss
    @State private var cardImage: UIImage?
    @State private var showShare = false
    @State private var appeared = false

    private var lostKg: Double { max(plan.startWeightKg - weightKg, 0) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.02, green: 0.16, blue: 0.08)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Theme.brand.opacity(0.16))
                        .frame(width: 190, height: 190)
                        .scaleEffect(appeared ? 1 : 0.6)
                    Image(systemName: "checkmark")
                        .font(.system(size: 84, weight: .black))
                        .foregroundStyle(Theme.brand)
                        .scaleEffect(appeared ? 1 : 0.4)
                }

                Text("MADE WEIGHT")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(1)

                Text("\(UnitConversion.string(weightKg, unit: athlete.unit)) \(athlete.unit.label) on the scale")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))

                HStack(spacing: 26) {
                    stat(title: "Lost", value: "\(UnitConversion.string(lostKg, unit: athlete.unit)) \(athlete.unit.label)")
                    stat(title: "Class", value: "\(athlete.weightClassLabel) lbs")
                    stat(title: "Days", value: "\(max(plan.weighInDate.timeIntervalSince(plan.createdAt) / 86400, 1).rounded(.down).formatted(.number.precision(.fractionLength(0))))")
                }
                .padding(.vertical, 8)

                Text("Now refuel. Sodium fluid and carbs, every hour.")
                    .font(.footnote)
                    .foregroundStyle(Theme.brand)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showShare = true
                    } label: {
                        Label("Share your card", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.brand, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.black)
                    }
                    Button("Close") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appeared = true }
            renderCard()
        }
        .sheet(isPresented: $showShare) {
            if let cardImage {
                ActivityView(items: [cardImage])
            }
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundStyle(.white)
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    @MainActor
    private func renderCard() {
        let card = ShareCard(athlete: athlete, plan: plan, weightKg: weightKg, lostKg: lostKg)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        cardImage = renderer.uiImage
    }
}

struct ShareCard: View {
    var athlete: Athlete
    var plan: CutPlan
    var weightKg: Double
    var lostKg: Double

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.03, blue: 0.035)
            VStack(spacing: 30) {
                HStack {
                    Text("CUTSZN")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.brand)
                    Spacer()
                    Text("#CutSzn")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(Theme.brand)
                Text("MADE\nWEIGHT")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-6)
                Text("\(UnitConversion.string(weightKg, unit: athlete.unit)) \(athlete.unit.label)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.brand)
                Text("\(athlete.sport.title) · \(athlete.weightClassLabel) lbs class")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("\(UnitConversion.string(lostKg, unit: athlete.unit))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(athlete.unit.label.uppercased()) CUT")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    VStack(spacing: 4) {
                        Text(plan.weighInDate, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("WEIGH-IN")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
        }
        .frame(width: 360, height: 640)
    }
}
