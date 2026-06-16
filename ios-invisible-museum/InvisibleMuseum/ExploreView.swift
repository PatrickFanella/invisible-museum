import SwiftUI

struct ExploreView: View {
    @Environment(MuseumStore.self) private var store
    @State private var path: [MuseumSpace] = []
    @State private var activeKindFilter: SpaceKind?
    @State private var showingFilterSheet = false

    var body: some View {
        NavigationStack(path: $path) {
            MuseumScreen {
                hero
                backendStatusBanner
                mapPreview
                sectionHeader
                ForEach(filteredSpaces) { space in
                    NavigationLink(value: space) {
                        SpaceRow(space: space, isDownloaded: store.isDownloaded(space))
                    }
                    .buttonStyle(.plain)
                }
                if filteredSpaces.isEmpty {
                    emptyFilterState
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MuseumSpace.self) { MuseumDetailView(space: $0) }
            .sheet(isPresented: $showingFilterSheet) { filterSheet }
        }
    }

    private var filteredSpaces: [MuseumSpace] {
        guard let activeKindFilter else { return store.spaces }
        return store.spaces.filter { $0.kind == activeKindFilter }
    }

    private var filterTitle: String {
        activeKindFilter?.label ?? "Filter"
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Overline(text: "The Invisible Museum")
                Spacer()
                MuseumChip(title: localityLabel, icon: "location.fill")
            }
            Text("Hidden galleries\naround Downers Grove")
                .font(Museum.title(36))
                .foregroundStyle(Museum.text)
                .lineSpacing(1)
            Text("Point your phone around town, scan nearby spaces, and watch local histories materialise in place.")
                .font(Museum.bodyFont(15))
                .foregroundStyle(Museum.muted)
        }
    }

    private var localityLabel: String { "Downers Grove, IL" }

    private var backendStatusBanner: some View {
        statusRow
    }

    @ViewBuilder
    private var statusRow: some View {
        switch store.nearbySpacesState {
        case .loading:
            compactStatusRow(
                icon: nil,
                title: "Syncing nearby spaces",
                subtitle: "Loading live backend…",
                tint: Museum.blue,
                trailing: AnyView(ProgressView().tint(Museum.blue))
            )
        case .loadedFromBackend:
            compactStatusRow(
                icon: "checkmark.seal.fill",
                title: "Live backend",
                subtitle: "Nearby spaces synced.",
                tint: Museum.green
            )
        case .sampleFallback(let reason):
            compactStatusRow(
                icon: "exclamationmark.triangle.fill",
                title: "Offline sample mode",
                subtitle: reason,
                tint: Museum.purple
            )
        }
    }

    private func compactStatusRow(icon: String?, title: String, subtitle: String, tint: Color, trailing: AnyView = AnyView(EmptyView())) -> some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.14), in: Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Museum.text)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Museum.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .museumGlassCard(radius: Museum.Radius.md, fill: Museum.surface.opacity(0.72))
    }

    private var mapPreview: some View {
        ZStack(alignment: .bottomLeading) {
            AbstractMap(spaces: store.spaces)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: Museum.Radius.xl, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Museum.Radius.xl, style: .continuous).stroke(Museum.border, lineWidth: 1))

            NavigationLink {
                MapListView()
            } label: {
                Label("Open Map", systemImage: "map.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Museum.text)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.58), in: Capsule())
                    .overlay(Capsule().stroke(Museum.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            if let first = store.spaces.first {
                NavigationLink(value: first) {
                    HStack(spacing: 13) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Museum.surfaceElevated)
                            .frame(width: 72, height: 72)
                            .overlay(Image(systemName: first.kind.symbol).font(.system(size: 30)).foregroundStyle(Museum.blue))
                        VStack(alignment: .leading, spacing: 4) {
                            Overline(text: first.kind.label, color: Museum.blue)
                            Text(first.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Museum.text)
                            Text(first.tagline)
                                .font(Museum.bodyFont(12))
                                .foregroundStyle(Museum.muted)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .museumGlassCard(radius: Museum.Radius.lg)
                    .padding(14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Overline(text: "Nearby spaces")
                Text("Nearby invisible museums")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Museum.text)
            }
            Spacer()
            Button { showingFilterSheet = true } label: {
                MuseumChip(title: filterTitle, isSelected: activeKindFilter != nil, icon: "line.3.horizontal.decrease")
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyFilterState: some View {
        MuseumCard(radius: Museum.Radius.lg, fill: Museum.surfaceElevated.opacity(0.52), stroke: Color.white.opacity(0.12), padding: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Label("No spaces in this filter", systemImage: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Museum.text)
                Text("Open the filter again or clear it to see every nearby space.")
                    .font(Museum.bodyFont(13))
                    .foregroundStyle(Museum.muted)
                Button("Show all spaces") {
                    activeKindFilter = nil
                }
                .buttonStyle(.museum(.secondary, size: .regular))
            }
        }
    }

    private var filterSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filter spaces")
                    .font(Museum.title(24))
                    .foregroundStyle(Museum.text)
                Spacer()
                Button("Done") { showingFilterSheet = false }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Museum.text)
            }

            Text("Choose one kind to narrow the nearby list.")
                .font(Museum.bodyFont(13))
                .foregroundStyle(Museum.muted)

            MuseumFlowLayout(spacing: 10) {
                Button { activeKindFilter = nil } label: {
                    MuseumChip(title: "All", isSelected: activeKindFilter == nil)
                }
                .buttonStyle(.plain)
                ForEach(SpaceKind.allCases, id: \.self) { kind in
                    Button { activeKindFilter = kind } label: {
                        MuseumChip(title: kind.label, isSelected: activeKindFilter == kind, icon: kind.symbol)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }
}

struct AbstractMap: View {
    let spaces: [MuseumSpace]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Museum.ink
                DottedGrid().stroke(Museum.blue.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [1, 12]))
                street(width: proxy.size.width * 1.05, height: 18).rotationEffect(.degrees(12)).offset(y: -proxy.size.height * 0.21)
                street(width: proxy.size.width * 1.08, height: 12).rotationEffect(.degrees(-7)).offset(y: proxy.size.height * 0.12)
                street(width: 18, height: proxy.size.height * 1.18).rotationEffect(.degrees(3)).offset(x: proxy.size.width * 0.16)
                street(width: 24, height: proxy.size.height * 1.18).offset(x: -proxy.size.width * 0.18)

                ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
                    MapPinBubble(space: space, active: index == 0)
                        .position(pinPosition(index, in: proxy.size))
                }
            }
        }
    }

    private func street(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Museum.surface)
            .frame(width: width, height: height)
    }

    private func pinPosition(_ index: Int, in size: CGSize) -> CGPoint {
        let points = [
            CGPoint(x: size.width * 0.30, y: size.height * 0.46),
            CGPoint(x: size.width * 0.63, y: size.height * 0.25),
            CGPoint(x: size.width * 0.74, y: size.height * 0.68),
            CGPoint(x: size.width * 0.18, y: size.height * 0.78)
        ]
        return points[index % points.count]
    }
}

struct DottedGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        stride(from: rect.minY, through: rect.maxY, by: 24).forEach { y in
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

struct MapPinBubble: View {
    let space: MuseumSpace
    let active: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(space.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Museum.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Museum.border, lineWidth: 1))
            Image(systemName: "mappin")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(active ? Museum.blue : Museum.surfaceElevated, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(active ? 0 : 0.18), lineWidth: 1))
                .blueGlow(active ? 0.55 : 0)
        }
    }
}

struct SpaceRow: View {
    let space: MuseumSpace
    let isDownloaded: Bool

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Museum.accentGradient.opacity(0.85))
                .frame(width: 78, height: 78)
                .overlay(Image(systemName: space.kind.symbol).font(.system(size: 30, weight: .semibold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 5) {
                Overline(text: space.kind.label, color: space.accent)
                Text(space.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Museum.text)
                Text(space.tagline)
                    .font(Museum.bodyFont(12))
                    .foregroundStyle(Museum.muted)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Label("\(Int(space.distanceMeters))m", systemImage: "location")
                    Label("\(space.exhibitCount)", systemImage: "sparkles")
                    if isDownloaded {
                        Label("Offline", systemImage: "arrow.down.circle.fill").foregroundStyle(Museum.green)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Museum.faint)
            }
            Spacer()
        }
        .padding(14)
        .museumGlassCard(radius: Museum.Radius.lg)
    }
}
