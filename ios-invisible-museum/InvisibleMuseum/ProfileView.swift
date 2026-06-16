import SwiftUI

struct ProfileView: View {
    @Environment(MuseumStore.self) private var store
    @Binding var selectedTab: MuseumTab
    @State private var showingModeration = false

    private let identityName = "Alex Curator"
    private let identityRole = "Local Explorer"
    private let identityLocation = "Downers Grove, IL"

    var body: some View {
        MuseumScreen(bottomInset: Museum.Spacing.bottomNavClearance + 8, topInset: 0) {
            hero
            statsGrid
            backendSection
            actionsSection
            aboutSection
        }
        .sheet(isPresented: $showingModeration) {
            ContributionModerationView()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: Museum.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Museum.blue.opacity(0.96), Museum.purple.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(.white.opacity(0.16))
                        .frame(width: 120, height: 120)
                        .offset(x: 30, y: -30)
                }
                .overlay(alignment: .center) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 150, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.11))
                        .offset(x: 68, y: 10)
                }

            VStack(alignment: .leading, spacing: 14) {
                Overline(text: "Profile / Status", color: .white.opacity(0.92))

                HStack(alignment: .center, spacing: 14) {
                    avatar

                    VStack(alignment: .leading, spacing: 6) {
                        Text(identityName)
                            .font(Museum.title(29))
                            .foregroundStyle(Museum.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(identityRole) • \(identityLocation)")
                        .font(Museum.bodyFont(14))
                        .foregroundStyle(Museum.text.opacity(0.78))
                        .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }

                Text("Prototype identity for browsing nearby spaces, saving exhibits, and reviewing offline cache.")
                    .font(Museum.bodyFont(13))
                    .foregroundStyle(Museum.text.opacity(0.82))
                    .lineSpacing(3)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        pill("Mock account", icon: "sparkles")
                        pill(cacheSummary, icon: "arrow.down.circle.fill")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        pill("Mock account", icon: "sparkles")
                        pill(cacheSummary, icon: "arrow.down.circle.fill")
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 238)
        .overlay(RoundedRectangle(cornerRadius: Museum.Radius.xl, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: Museum.blue.opacity(0.16), radius: 28, x: 0, y: 14)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.26))
                .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
            Circle()
                .fill(Museum.accentGradient)
                .padding(5)
            Text(initials)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 84, height: 84)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            statCard(value: "\(store.spaces.count)", label: "Spaces discovered", tint: Museum.blue)
            statCard(value: "\(store.savedExhibits.count)", label: "Saved exhibits", tint: Museum.purple)
            statCard(value: "\(store.downloadedSpaceIDs.count)", label: "Downloaded spaces", tint: Museum.green)
            statCard(value: contributionsValue, label: "Contributions", tint: Museum.text)
        }
    }

    private var backendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Overline(text: "Backend mode")
            MuseumCard(radius: Museum.Radius.lg, fill: Museum.surfaceElevated.opacity(0.62), stroke: Museum.borderStrong, padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(backendTitle)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Museum.text)
                            Text(backendSubtitle)
                                .font(Museum.bodyFont(13))
                                .foregroundStyle(Museum.muted)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 8)

                        statusPill
                    }

                    apiBaseURLRow

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            infoPill("API mode", icon: "server.rack")
                            infoPill("Local cache", icon: "internaldrive")
                            infoPill(backendShortLabel, icon: backendIcon)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            infoPill("API mode", icon: "server.rack")
                            infoPill("Local cache", icon: "internaldrive")
                            infoPill(backendShortLabel, icon: backendIcon)
                        }
                    }

                    Button {
                        Task { await store.loadNearbySpaces() }
                    } label: {
                        Label("Refresh status", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.museum(.secondary, size: .regular))
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Overline(text: "Settings & actions")

            actionCard(
                title: "Offline cache",
                subtitle: "\(store.downloadedSpaceIDs.count) cached spaces are ready for offline browsing.",
                icon: "arrow.down.circle.fill",
                tint: Museum.green
            ) {
                Button {
                    selectedTab = .saved
                } label: {
                    Label("Open collection", systemImage: "heart.fill")
                }
                .buttonStyle(.museum(.secondary, size: .regular))
            }

            actionCard(
                title: "Prototype mode",
                subtitle: "This screen is a polished mock identity — no authentication or personal data sync.",
                icon: "sparkles",
                tint: Museum.purple
            ) {
                Button {
                    showingModeration = true
                } label: {
                    Label("Open moderation", systemImage: "checklist")
                }
                .buttonStyle(.museum(.secondary, size: .regular))

                Button {
                    selectedTab = .explore
                } label: {
                    Label("Back to explore", systemImage: "map.fill")
                }
                .buttonStyle(.museum(.secondary, size: .regular))
            }
        }
    }

    private var aboutSection: some View {
        MuseumCard(radius: Museum.Radius.lg, fill: Museum.surface.opacity(0.62), stroke: Museum.border, padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Overline(text: "About prototype", color: Museum.blue)
                Text("Invisible Museum is a spatial archive prototype for discovering, saving, and contributing local stories.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Museum.text)
                    .lineSpacing(3)
                Text("Use it like a live field guide: explore the map, cache spaces offline, and submit ideas without signing in.")
                    .font(Museum.bodyFont(13))
                    .foregroundStyle(Museum.muted)
                    .lineSpacing(3)
            }
        }
    }

    private func statCard(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Museum.faint)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(14)
        .museumGlassCard(radius: Museum.Radius.md, fill: Museum.surfaceElevated.opacity(0.66))
    }

    private func actionCard<Content: View>(title: String, subtitle: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        MuseumCard(radius: Museum.Radius.lg, fill: Museum.surfaceElevated.opacity(0.52), stroke: Museum.border, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 38, height: 38)
                        .background(tint.opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Museum.text)
                        Text(subtitle)
                            .font(Museum.bodyFont(13))
                            .foregroundStyle(Museum.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                content()
            }
        }
    }

    private func pill(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.white.opacity(0.94))
            .background(.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
    }

    private func infoPill(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Museum.text.opacity(0.84))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Museum.background.opacity(0.55), in: Capsule())
            .overlay(Capsule().stroke(Museum.border, lineWidth: 1))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var initials: String {
        let parts = identityName.split(separator: " ")
        let initials = parts.compactMap { $0.first }.prefix(2)
        return String(initials)
    }

    private var contributionsValue: String { "\(store.contributionCount)" }

    private var cacheSummary: String { "\(store.downloadedSpaceIDs.count) cached" }

    private var backendTitle: String {
        switch store.nearbySpacesState {
        case .loading: "Syncing nearby spaces"
        case .loadedFromBackend: "Live backend connected"
        case .sampleFallback: "Offline sample mode"
        }
    }

    private var backendSubtitle: String {
        switch store.nearbySpacesState {
        case .loading:
            return "Waiting for nearby spaces from the backend."
        case .loadedFromBackend:
            return "Nearby spaces are being served from the remote API."
        case .sampleFallback(let reason):
            return reason
        }
    }

    private var backendShortLabel: String {
        switch store.nearbySpacesState {
        case .loading: "Syncing"
        case .loadedFromBackend: "Remote"
        case .sampleFallback: "Fallback"
        }
    }

    private var backendIcon: String {
        switch store.nearbySpacesState {
        case .loading: "hourglass"
        case .loadedFromBackend: "checkmark.seal.fill"
        case .sampleFallback: "exclamationmark.triangle.fill"
        }
    }

    private var statusPill: some View {
        Label(backendShortLabel.uppercased(), systemImage: backendIcon)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(statusTint)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(statusTint.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(statusTint.opacity(0.25), lineWidth: 1))
    }

    private var apiBaseURLRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Museum.blue)
                .frame(width: 28, height: 28)
                .background(Museum.blue.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("API base URL")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Museum.faint)
                Text(BackendConfiguration.displayBaseURL)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Museum.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Text(BackendConfiguration.sourceDescription.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Museum.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Museum.background.opacity(0.55), in: Capsule())
                .overlay(Capsule().stroke(Museum.border, lineWidth: 1))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Museum.background.opacity(0.38), in: RoundedRectangle(cornerRadius: Museum.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Museum.Radius.md, style: .continuous).stroke(Museum.border, lineWidth: 1))
    }

    private var statusTint: Color {
        switch store.nearbySpacesState {
        case .loading: Museum.blue
        case .loadedFromBackend: Museum.green
        case .sampleFallback: Museum.purple
        }
    }
}
