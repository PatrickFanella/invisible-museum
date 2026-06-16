import SwiftUI

struct SavedView: View {
    @Environment(MuseumStore.self) private var store
    @Binding var selectedTab: MuseumTab
    @State private var filter = "All"
    private let filters = ["All", "Downloaded", "Audio", "Visual", "3D Objects"]
    @State private var selectedExhibit: SavedExhibitSelection?

    private var exhibits: [(space: MuseumSpace, exhibit: Exhibit)] {
        let saved = store.savedExhibits
        guard !saved.isEmpty else { return [] }

        return saved.filter { item in
            switch filter {
            case "All": true
            case "Downloaded": store.isDownloaded(item.space)
            case "Audio": item.exhibit.kind == .audio
            case "Visual": item.exhibit.kind == .image
            case "3D Objects": item.exhibit.kind == .artifact
            default: true
            }
        }
    }

    var body: some View {
        NavigationStack {
            MuseumScreen {
                header
                if store.savedExhibits.isEmpty {
                    emptyState
                } else {
                    ForEach(exhibits, id: \.exhibit.id) { item in
                        CollectionCard(
                            space: item.space,
                            exhibit: item.exhibit,
                            downloaded: store.isDownloaded(item.space),
                            saved: store.isSaved(item.exhibit)
                        ) {
                            selectedExhibit = SavedExhibitSelection(space: item.space, exhibit: item.exhibit)
                        } toggleSaved: {
                            store.toggleSaved(item.exhibit)
                        }
                    }
                    if exhibits.isEmpty {
                        filteredEmptyState
                    }
                }
                discoverMore
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedExhibit) { selection in
                ExhibitDetailView(space: selection.space, exhibit: selection.exhibit)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Collection")
                .font(Museum.title(28))
                .foregroundStyle(Museum.text)
                .padding(.top, 12)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { item in
                        Button { withAnimation(.snappy) { filter = item } } label: {
                            MuseumChip(title: item, isSelected: filter == item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, 12)
    }

    private var discoverMore: some View {
        Button {
            selectedTab = .explore
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Museum.muted)
                    .frame(width: 52, height: 52)
                    .background(Museum.surfaceElevated, in: Circle())
                Text("Discover from Explore")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Museum.text)
                Text("Open the map tab to find more nearby spaces and save them here.")
                    .font(Museum.bodyFont(13))
                    .foregroundStyle(Museum.muted)
                    .multilineTextAlignment(.center)
                MuseumChip(title: "Open Explore", icon: "map.fill")
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .buttonStyle(.plain)
        .museumGlassCard(radius: Museum.Radius.lg, fill: Museum.surfaceElevated.opacity(0.45))
        .overlay(RoundedRectangle(cornerRadius: Museum.Radius.lg, style: .continuous).stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [6, 6])))
    }

    private var emptyState: some View {
        MuseumCard(radius: Museum.Radius.lg, fill: Museum.surfaceElevated.opacity(0.52), stroke: Color.white.opacity(0.12), padding: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "heart.slash")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Museum.purple)
                    .frame(width: 48, height: 48)
                    .background(Museum.purple.opacity(0.14), in: Circle())
                Text("No saved exhibits yet")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Museum.text)
                Text("Save an exhibit from Explore, then it will appear in your collection.")
                    .font(Museum.bodyFont(13))
                    .foregroundStyle(Museum.muted)
                Button {
                    selectedTab = .explore
                } label: {
                    Label("Discover from Explore", systemImage: "map.fill")
                }
                .buttonStyle(.museum(.secondary, size: .regular))
            }
        }
    }

    private var filteredEmptyState: some View {
        MuseumCard(radius: Museum.Radius.lg, fill: Museum.surfaceElevated.opacity(0.48), stroke: Color.white.opacity(0.12), padding: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("No saved exhibits match this filter")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Museum.text)
                Text("Try a different category or clear the filter.")
                    .font(Museum.bodyFont(13))
                    .foregroundStyle(Museum.muted)
            }
        }
    }
}

struct CollectionCard: View {
    let space: MuseumSpace
    let exhibit: Exhibit
    let downloaded: Bool
    let saved: Bool
    let openDetail: () -> Void
    let toggleSaved: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                MuseumMediaCard(
                    radius: Museum.Radius.lg,
                    gradient: Museum.accentGradient,
                    symbol: exhibit.kind.symbol,
                    symbolSize: 48,
                    height: 136
                ) { EmptyView() }
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Museum.background], startPoint: .top, endPoint: .bottom)
                        .frame(height: 80)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Overline(text: exhibit.kind.label, color: space.accent)
                            Text(exhibit.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Museum.text)
                        }
                        Spacer()
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(downloaded ? Museum.green : Museum.faint)
                            .font(.system(size: 21))
                    }
                    Label("Saved from \(space.name) · \(exhibit.year)", systemImage: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Museum.faint)
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: Museum.Radius.lg, style: .continuous))
            .museumGlassCard(radius: Museum.Radius.lg)
            .contentShape(RoundedRectangle(cornerRadius: Museum.Radius.lg, style: .continuous))
            .onTapGesture(perform: openDetail)

            Button(action: toggleSaved) {
                Image(systemName: saved ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.42), in: Circle())
            }
            .padding(12)
        }
    }
}

private struct SavedExhibitSelection: Identifiable {
    let id: String
    let space: MuseumSpace
    let exhibit: Exhibit

    init(space: MuseumSpace, exhibit: Exhibit) {
        self.id = exhibit.id
        self.space = space
        self.exhibit = exhibit
    }
}
