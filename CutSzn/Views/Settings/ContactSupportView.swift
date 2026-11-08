import SwiftUI

struct SupportTopic: Identifiable, Hashable {
    var title: String
    var icon: String
    var id: String { title }
}

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss

    private let topics: [SupportTopic] = [
        SupportTopic(title: "General", icon: "bubble.left.fill"),
        SupportTopic(title: "Feature Suggestion", icon: "lightbulb.fill"),
        SupportTopic(title: "Bug Report", icon: "ant.fill"),
        SupportTopic(title: "Usage Question", icon: "questionmark.circle.fill"),
        SupportTopic(title: "Performance Issue", icon: "gauge.with.dots.needle.67percent"),
        SupportTopic(title: "UI Improvement", icon: "paintpalette.fill"),
        SupportTopic(title: "Other", icon: "ellipsis.circle.fill")
    ]

    @State private var selected = "General"
    @State private var customSubject = ""
    @State private var name = ""
    @State private var email = ""
    @State private var message = ""
    @State private var sending = false
    @State private var status: Status?

    private enum Status {
        case success
        case failure(String)
    }

    private var resolvedSubject: String {
        selected == "Other" ? customSubject : selected
    }

    private var emailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && !trimmed.contains(" ")
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        emailValid &&
        !message.trimmingCharacters(in: .whitespaces).isEmpty &&
        !resolvedSubject.trimmingCharacters(in: .whitespaces).isEmpty &&
        !sending
    }

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(topics.filter { $0.title != "Other" }) { topic in
                        topicTile(topic)
                    }
                    topicTile(topics.first { $0.title == "Other" }!)
                        .gridCellColumns(2)
                }
                .padding(.vertical, 4)

                if selected == "Other" {
                    TextField("What is this about?", text: $customSubject)
                }
            } header: {
                Text("Subject")
            } footer: {
                Text("Pick the closest topic. Only Other needs a custom subject.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }

            Section {
                TextField("Your name", text: $name)
                    .textContentType(.name)
                TextField("yourname@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !email.isEmpty && !emailValid {
                    Text("Enter a valid email address.")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            } header: {
                Text("About you")
            }

            Section {
                TextEditor(text: $message)
                    .frame(minHeight: 130)
                    .overlay(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Tell us what's on your mind…")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                HStack {
                    Spacer()
                    Text("\(message.count) / 1000")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            } header: {
                Text("Message")
            }

            Section {
                Button {
                    submit()
                } label: {
                    HStack {
                        if sending { ProgressView().tint(.black) }
                        Text(sending ? "Sending…" : "Submit")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Theme.brand)
                .foregroundStyle(.black)
                .disabled(!canSubmit)

                if let status {
                    switch status {
                    case .success:
                        Label("Thank you! Your feedback has been sent.", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.brand)
                    case .failure(let text):
                        Label(text, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                    }
                }

                Text("We only use your email to respond to this feedback.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: message) { _, newValue in
            if newValue.count > 1000 {
                message = String(newValue.prefix(1000))
            }
        }
    }

    private func topicTile(_ topic: SupportTopic) -> some View {
        let active = selected == topic.title
        return Button {
            selected = topic.title
        } label: {
            HStack(spacing: 10) {
                Image(systemName: topic.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(active ? .white : Theme.brand)
                Text(topic.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(active ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if active {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(active ? Theme.brand : Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? Theme.brand : Color(uiColor: .separator), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Subject \(topic.title)")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func submit() {
        sending = true
        status = nil
        let subject = resolvedSubject
        Task {
            do {
                try await FeedbackService.send(name: name, email: email, subject: subject,
                                                message: message, appName: "CutSzn")
                await MainActor.run {
                    status = .success
                    sending = false
                    name = ""
                    email = ""
                    message = ""
                    customSubject = ""
                    selected = "General"
                }
            } catch {
                await MainActor.run {
                    status = .failure("Something went wrong. Please try again.")
                    sending = false
                }
            }
        }
    }
}
