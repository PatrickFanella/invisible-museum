import SwiftUI

struct ContributionModerationView: View {
    @Environment(MuseumStore.self) private var store

    var body: some View {
        NavigationStack {
            MuseumScreen {
                header
                statusBanner
                if store.moderationQueue.isEmpty {
                    emptyState
                } else {
                    ForEach(store.moderationQueue) { contribution in
                        contributionCard(contribution)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await store.loadModerationQueue() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Overline(text: "Admin / Moderation")
            Text("Contribution review queue")
                .font(Museum.title(28))
                .foregroundStyle(Museum.text)
            Text("Approve or reject pending contributions before they reach the museum.")
                .font(Museum.bodyFont(14))
                .foregroundStyle(Museum.muted)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch store.moderationQueueState {
        case .loading:
            HStack(spacing: 12) {
                ProgressView().tint(Museum.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Loading moderation queue")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Museum.text)
                    Text("Pulling the latest pending contributions.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Museum.muted)
                }
                Spacer()
            }
            .padding(14)
            .museumGlassCard(radius: Museum.Radius.md, fill: Museum.surfaceElevated.opacity(0.7))
        case .loadedFromBackend:
            moderationNotice(
                title: "Live backend connected",
                subtitle: "Review decisions are sent to the API.",
                tint: Museum.green,
                icon: "checkmark.seal.fill"
            )
        case .sampleFallback(let reason):
            moderationNotice(
                title: "Sample moderation queue",
                subtitle: reason,
                tint: Museum.purple,
                icon: "exclamationmark.triangle.fill"
            )
        }

        if let message = store.moderationMessage {
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Museum.muted)
                .padding(.horizontal, 2)
        }

        HStack {
            Text("Pending: \(store.moderationQueue.count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Museum.faint)
            Spacer()
            Button {
                Task { await store.loadModerationQueue() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.museum(.secondary, size: .small))
        }
    }

    private func moderationNotice(title: String, subtitle: String, tint: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Museum.text)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Museum.muted)
            }
            Spacer()
        }
        .padding(14)
        .museumGlassCard(radius: Museum.Radius.md, fill: Museum.surfaceElevated.opacity(0.7))
    }

    private func contributionCard(_ contribution: ContributionModerationItem) -> some View {
        MuseumCard(radius: Museum.Radius.lg, fill: Museum.surfaceElevated.opacity(0.56), stroke: Museum.border, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Overline(text: contribution.kind.label, color: Museum.blue)
                        Text(contribution.suggestedTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Museum.text)
                        Text(contribution.contributorName)
                            .font(Museum.bodyFont(12))
                            .foregroundStyle(Museum.muted)
                    }
                    Spacer(minLength: 8)
                    statusPill(contribution.status)
                }

                if let spaceID = contribution.spaceID {
                    Label(spaceID, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Museum.faint)
                }

                Text(contribution.body)
                    .font(Museum.bodyFont(13))
                    .foregroundStyle(Museum.text.opacity(0.86))
                    .lineSpacing(3)

                Text(contribution.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Museum.faint)

                HStack(spacing: 10) {
                    Button {
                        Task { await store.reviewContribution(id: contribution.id, status: .approved) }
                    } label: {
                        Label("Approve", systemImage: "checkmark")
                    }
                    .buttonStyle(.museum(.primary, size: .regular))

                    Button {
                        Task { await store.reviewContribution(id: contribution.id, status: .rejected) }
                    } label: {
                        Label("Reject", systemImage: "xmark")
                    }
                    .buttonStyle(.museum(.destructive, size: .regular))
                }
            }
        }
    }

    private func statusPill(_ status: ContributionModerationStatus) -> some View {
        let tint: Color = {
            switch status {
            case .pending: Museum.blue
            case .approved: Museum.green
            case .rejected: Museum.danger
            }
        }()

        return Text(status.label.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 1))
    }

    private var emptyState: some View {
        MuseumCard(radius: Museum.Radius.lg, fill: Museum.surfaceElevated.opacity(0.5), stroke: Museum.border, padding: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Label("No pending contributions", systemImage: "checkmark.seal")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Museum.text)
                Text("The queue is empty right now. Refresh to check for new submissions.")
                    .font(Museum.bodyFont(13))
                    .foregroundStyle(Museum.muted)
            }
        }
    }
}
