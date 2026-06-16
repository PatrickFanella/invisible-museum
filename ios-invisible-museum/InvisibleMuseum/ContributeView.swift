import SwiftUI

struct ContributeView: View {
    @Environment(MuseumStore.self) private var store
    @State private var selectedKind: ExhibitKind = .story
    @State private var title = ""
    @State private var bodyText = ""
    @State private var source = ""
    @State private var selectedSpaceID = SampleData.spaces.first?.id ?? ""
    @State private var submissionState: SubmissionState = .idle

    private let titleLimit = 80
    private let bodyMinimumLength = 24

    private enum SubmissionState: Equatable {
        case idle
        case submitting
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            MuseumScreen {
                header
                spacePicker
                typePicker
                MuseumTextField(
                    label: "Title",
                    placeholder: "Give your contribution a name",
                    text: $title,
                    helperText: titleHelperText,
                    helperTint: titleHelperTint,
                    helperIsError: titleHelperIsError
                )
                MuseumTextEditor(
                    label: "Story",
                    placeholder: "Share the memory, source, or context",
                    text: $bodyText,
                    minHeight: 160,
                    helperText: bodyHelperText,
                    helperTint: bodyHelperTint,
                    helperIsError: bodyHelperIsError
                )
                MuseumTextField(label: "Contributor", placeholder: "Optional name for the review queue", text: $source)
                submitButton
                submissionMessage
                safetyNote
            }
            .overlay { if case .success = submissionState { submittedOverlay } }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: store.spaces.map(\.id)) { syncSelectedSpace() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contribute")
                .font(Museum.title(28))
                .foregroundStyle(Museum.text)
            Text("Add a memory, image, sound, or object. Curators review every proposal before it joins the museum.")
                .font(Museum.bodyFont(14))
                .foregroundStyle(Museum.muted)
        }
        .padding(.top, 12)
    }

    private var spacePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Overline(text: "Space")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(store.spaces) { space in
                        Button { selectedSpaceID = space.id } label: {
                            MuseumChip(title: space.name, isSelected: selectedSpaceID == space.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            MuseumInlineHint(text: spaceHelperText, tint: spaceHelperTint, isError: selectedSpace == nil)
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Overline(text: "Format")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ExhibitKind.allCases, id: \.self) { kind in
                    Button { selectedKind = kind } label: {
                        HStack {
                            Image(systemName: kind.symbol)
                            Text(kind.label)
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectedKind == kind ? .black : Museum.text)
                        .padding(13)
                        .background(selectedKind == kind ? Color.white : Museum.surface, in: RoundedRectangle(cornerRadius: Museum.Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Museum.Radius.md).stroke(selectedKind == kind ? Color.clear : Museum.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var submitButton: some View {
        Button { Task { await submitContribution() } } label: {
            ZStack {
                Label("Submit for Review", systemImage: "paperplane.fill")
                    .opacity(isSubmitting ? 0 : 1)
                if isSubmitting {
                    ProgressView()
                        .tint(.black)
                }
            }
        }
        .buttonStyle(.museum(.primary, size: .large))
        .disabled(!canSubmit)
    }

    private var submissionMessage: some View {
        Group {
            if case .failure(let message) = submissionState {
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Museum.danger.opacity(0.95))
            }
        }
    }

    private var safetyNote: some View {
        Label("Submissions stay private until reviewed for consent, safety, and source clarity.", systemImage: "shield.checkered")
            .font(.system(size: 12))
            .foregroundStyle(Museum.muted)
            .padding(14)
            .museumGlassCard(radius: Museum.Radius.md)
    }

    private var submittedOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 42)).foregroundStyle(Museum.green)
                Text("Proposal received").font(Museum.title(22)).foregroundStyle(Museum.text)
                Text("A curator will review it before publication.").font(Museum.bodyFont(14)).foregroundStyle(Museum.muted)
                Button("Done") { submissionState = .idle }
                    .buttonStyle(.museum(.secondary, size: .regular))
            }
            .padding(26)
            .museumGlassCard(radius: Museum.Radius.xl)
            .padding(30)
        }
    }

    private var isSubmitting: Bool {
        if case .submitting = submissionState { return true }
        return false
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBody: String {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSource: String {
        source.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedSpace: MuseumSpace? {
        store.space(id: selectedSpaceID)
    }

    private var titleValidationMessage: String? {
        if trimmedTitle.isEmpty { return "Title required. Up to \(titleLimit) characters." }
        if trimmedTitle.count > titleLimit { return "Keep it under \(titleLimit) characters." }
        return "Up to \(titleLimit) characters."
    }

    private var titleHelperText: String { titleValidationMessage ?? "Up to \(titleLimit) characters." }

    private var titleHelperTint: Color {
        titleHelperIsError ? Museum.danger : Museum.muted
    }

    private var titleHelperIsError: Bool {
        trimmedTitle.isEmpty || trimmedTitle.count > titleLimit
    }

    private var bodyValidationMessage: String? {
        if trimmedBody.isEmpty { return "Story required. Add at least \(bodyMinimumLength) characters with source or context." }
        if trimmedBody.count < bodyMinimumLength { return "Add at least \(bodyMinimumLength) characters." }
        return "Add source or memory for review."
    }

    private var bodyHelperText: String { bodyValidationMessage ?? "Add source or memory for review." }

    private var bodyHelperTint: Color {
        bodyHelperIsError ? Museum.danger : Museum.muted
    }

    private var bodyHelperIsError: Bool {
        trimmedBody.isEmpty || trimmedBody.count < bodyMinimumLength
    }

    private var spaceHelperText: String {
        selectedSpace.map { "Selected: \($0.name)." } ?? "Choose a nearby space."
    }

    private var spaceHelperTint: Color {
        selectedSpace == nil ? Museum.danger : Museum.muted
    }

    private var canSubmit: Bool {
        !isSubmitting && selectedSpace != nil && !trimmedTitle.isEmpty && trimmedTitle.count <= titleLimit && !trimmedBody.isEmpty && trimmedBody.count >= bodyMinimumLength
    }

    @MainActor
    private func submitContribution() async {
        guard !isSubmitting else { return }

        guard canSubmit, let spaceID = selectedSpace?.id else {
            submissionState = .idle
            return
        }

        let contributorName = trimmedSource.isEmpty ? "Anonymous contributor" : trimmedSource

        submissionState = .submitting

        do {
            let submission = try await store.submitContribution(
                spaceID: spaceID,
                suggestedTitle: trimmedTitle,
                kind: selectedKind,
                body: trimmedBody,
                contributorName: contributorName
            )

            guard submission.status == .pending else {
                submissionState = .failure("Submission failed. Try again.")
                return
            }

            withAnimation(.spring) {
                submissionState = .success
            }
        } catch let error as MuseumAPIClient.APIError {
            switch error {
            case .backendUnavailable:
                submissionState = .failure("Backend unavailable. Try again later.")
            case .validationFailed:
                submissionState = .failure("Please check the title and story.")
            default:
                submissionState = .failure("Submission failed. Try again.")
            }
        } catch {
            submissionState = .failure("Submission failed. Try again.")
        }
    }

    private func syncSelectedSpace() {
        guard let firstSpaceID = store.spaces.first?.id else {
            selectedSpaceID = ""
            return
        }

        if store.space(id: selectedSpaceID) == nil {
            selectedSpaceID = firstSpaceID
        }
    }
}
