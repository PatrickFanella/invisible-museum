import SwiftUI

struct ExhibitDetailView: View {
    let space: MuseumSpace
    let exhibit: Exhibit
    @Environment(MuseumStore.self) private var store
    @State private var isPlaying = false

    var body: some View {
        MuseumScreen(bottomInset: 26, topInset: 0) {
            handle
            headerImage
            header
            Text(exhibit.body)
                .font(Museum.bodyFont(15))
                .foregroundStyle(Museum.text.opacity(0.80))
                .lineSpacing(4)
            if exhibit.kind == .audio { audioPlayer }
            tags
            Button { store.toggleSaved(exhibit) } label: {
                Label(store.isSaved(exhibit) ? "Saved" : "Save to Collection", systemImage: store.isSaved(exhibit) ? "heart.fill" : "heart")
            }
            .buttonStyle(.museum(.primary, size: .large))
        }
        .scrollIndicators(.hidden)
        .background(Museum.ink.opacity(0.96))
    }

    private var handle: some View {
        Capsule()
            .fill(Color.white.opacity(0.20))
            .frame(width: 48, height: 5)
            .frame(maxWidth: .infinity)
    }

    private var headerImage: some View {
        MuseumMediaCard(
            radius: Museum.Radius.lg,
            gradient: Museum.accentGradient,
            symbol: exhibit.kind.symbol,
            symbolSize: 58,
            height: 190
        ) {
            EmptyView()
        }
        .overlay(alignment: .bottomLeading) {
            HStack {
                pill("Audio", icon: "play.fill")
                pill("5 Archives", icon: "photo")
            }
            .padding(12)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Overline(text: exhibit.kind.label, color: space.accent)
                Text(exhibit.title)
                    .font(Museum.title(26))
                    .foregroundStyle(Museum.text)
                Text("\(exhibit.year) · \(exhibit.contributor)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Museum.muted)
            }
            Spacer()
        }
    }

    private var audioPlayer: some View {
        HStack(spacing: 12) {
            Button { isPlaying.toggle() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .background(Color.white, in: Circle())
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Begin Experience")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Museum.text)
                ProgressView(value: isPlaying ? 0.45 : 0.12)
                    .tint(Museum.blue)
            }
        }
        .padding(14)
        .museumGlassCard(radius: Museum.Radius.md)
    }

    private var tags: some View {
        MuseumFlowLayout(spacing: 8) {
            ForEach(exhibit.tags, id: \.self) { tag in
                MuseumChip(title: tag)
            }
        }
    }

    private func pill(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.46), in: Capsule())
    }
}
