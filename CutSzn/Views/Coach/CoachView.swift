import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ChatMessage: Identifiable {
    enum Role { case user, coach }
    var id = UUID()
    var role: Role
    var text: String
    var source: String?
}

struct CoachView: View {
    @Bindable var athlete: Athlete
    @Bindable var plan: CutPlan
    @Query(sort: \WeighIn.date, order: .reverse) private var weighIns: [WeighIn]
    @Query private var progressRows: [DayProgress]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @StateObject private var purchases = PurchaseManager.shared
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var loading = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var analysis: MealAnalysis?
    @State private var scanNote: String?
    @State private var scanning = false

    private var snapshot: DailySnapshot {
        PlanCalculator.snapshot(athlete: athlete, plan: plan, weighIns: weighIns)
    }

    private var aiContext: AIContext {
        AIContext(currentKg: snapshot.currentKg, targetKg: plan.targetWeightKg, daysOut: snapshot.daysOut,
                  waterML: snapshot.targets.waterML, sodiumMG: snapshot.targets.sodiumMG,
                  carbsG: snapshot.targets.carbsG, fiberG: snapshot.targets.fiberG, unit: athlete.unit)
    }

    private var suggestions: [String] {
        ["Can I eat this?", "I'm over tonight — what do I do?", "How much water today?", "Explain my sodium target"]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        contextCard
                        if let analysis { analysisCard(analysis) }
                        if let scanNote {
                            Text(scanNote)
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                        }
                        ForEach(messages) { message in
                            bubble(message)
                        }
                        if loading {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Thinking…").font(.caption).foregroundStyle(Theme.muted)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(20)
                }

                suggestionBar
                inputBar
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Corner Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { _, newValue in
                guard let newValue else { return }
                loadPhoto(newValue)
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    capturedImage = image
                    if let data = image.jpegData(compressionQuality: 0.7) {
                        scan(data)
                    }
                }
            }
        }
    }

    private var contextCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(Theme.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text("Grounded in today's plan")
                    .font(.subheadline.weight(.semibold))
                Text("\(UnitConversion.string(snapshot.currentKg, unit: athlete.unit)) \(athlete.unit.label) now · \(snapshot.daysOut) days out")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                if let source = message.source {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(12)
            .background(message.role == .user ? Theme.brand.opacity(0.85) : Theme.card,
                        in: RoundedRectangle(cornerRadius: 16))
            if message.role == .coach { Spacer(minLength: 40) }
        }
    }

    private var suggestionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { text in
                    Button {
                        send(text)
                    } label: {
                        Text(text)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.card, in: Capsule())
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    scanNote = "The camera is not available on this device. Choose a photo instead."
                }
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                    .frame(width: 40, height: 40)
                    .background(Theme.card, in: Circle())
            }
            .accessibilityLabel("Scan a meal with the camera")

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                    .frame(width: 40, height: 40)
                    .background(Theme.card, in: Circle())
            }
            .accessibilityLabel("Choose a meal photo")

            TextField("Ask your coach…", text: $input, axis: .vertical)
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))

            Button {
                send(input)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(input.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.muted : Theme.brand)
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || loading)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !loading else { return }
        messages.append(ChatMessage(role: .user, text: question))
        input = ""
        loading = true
        Task {
            let result = await AIRouter.answer(question: question, context: aiContext, isPro: purchases.isPro)
            await MainActor.run {
                messages.append(ChatMessage(role: .coach, text: result.text, source: result.sourceLabel))
                loading = false
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) {
        scanning = true
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    scanNote = "That photo could not be read."
                    scanning = false
                }
                return
            }
            scan(data)
        }
    }

    private func scan(_ data: Data) {
        scanning = true
        scanNote = nil
        analysis = nil
        Task {
            let (result, note) = await AIRouter.analyzeMeal(imageData: data, context: aiContext, isPro: purchases.isPro)
            await MainActor.run {
                analysis = result
                scanNote = result == nil ? note : nil
                scanning = false
            }
        }
    }

    private func analysisCard(_ analysis: MealAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Meal scan", systemImage: "camera.viewfinder")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(analysis.verdict.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(verdictColor(analysis.verdict))
            }
            ForEach(analysis.items) { item in
                HStack {
                    Text(item.name).font(.caption)
                    Spacer()
                    Text("\(Int(item.carbsG)) g C · \(Int(item.sodiumMG)) mg Na")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
            Divider()
            HStack {
                Text("Totals").font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(analysis.totalCarbs)) g carbs · \(Int(analysis.totalSodium)) mg sodium · \(Int(analysis.totalKcal)) kcal")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
            Button {
                addToToday(analysis)
            } label: {
                Text("Add to today's totals")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.brandDim, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Theme.brand)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func verdictColor(_ verdict: String) -> Color {
        switch verdict {
        case "avoid": return Theme.danger
        case "eat": return Theme.brand
        default: return Theme.amber
        }
    }

    private func addToToday(_ analysis: MealAnalysis) {
        for item in analysis.items {
            let log = MealLog(name: item.name, carbsG: item.carbsG, sodiumMG: item.sodiumMG,
                              fiberG: item.fiberG, kcal: item.kcal, verdict: analysis.verdict)
            context.insert(log)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: Date())
        let row = progressRows.first { $0.dayKey == key } ?? {
            let created = DayProgress(dayKey: key)
            context.insert(created)
            return created
        }()
        row.mealCarbsG += analysis.totalCarbs
        row.mealSodiumMG += analysis.totalSodium
        row.mealFiberG += analysis.totalFiber
        try? context.save()
        scanNote = "Added to today's totals."
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            picker.dismiss(animated: true)
        }
    }
}
