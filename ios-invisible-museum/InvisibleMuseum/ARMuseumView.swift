import SwiftUI

struct ARMuseumView: View {
    let space: MuseumSpace
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExhibit: Exhibit?

    var body: some View {
        ZStack {
            cameraSimulation
            ARMarkers(space: space, selectedExhibit: $selectedExhibit)
            ARHUD(space: space, onExit: { dismiss() })
        }
        .sheet(item: $selectedExhibit) { exhibit in
            ExhibitDetailView(space: space, exhibit: exhibit)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .statusBarHidden()
    }

    private var cameraSimulation: some View {
        LinearGradient(colors: [Color(red: 0.13, green: 0.15, blue: 0.17), Museum.background], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .overlay {
                ZStack {
                    ForEach(0..<8) { i in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.035))
                            .frame(width: CGFloat(120 + i * 18), height: 10)
                            .rotationEffect(.degrees(Double(i * 17)))
                            .offset(x: CGFloat(i * 17 - 70), y: CGFloat(i * 28 - 80))
                    }
                }
            }
    }
}

struct ARMarkers: View {
    let space: MuseumSpace
    @Binding var selectedExhibit: Exhibit?

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(space.exhibits.prefix(3).enumerated()), id: \.element.id) { index, exhibit in
                Button { selectedExhibit = exhibit } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            PulseRing(delay: Double(index) * 0.3)
                            Image(systemName: "sparkles")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(Museum.blue)
                                .frame(width: 44, height: 44)
                                .background(Museum.surface.opacity(0.82), in: Circle())
                                .overlay(Circle().stroke(Museum.borderStrong, lineWidth: 1))
                                .blueGlow(0.60)
                        }
                        VStack(spacing: 2) {
                            Text(exhibit.title).font(.system(size: 12, weight: .bold))
                            Text(index == 0 ? "12m" : "\(6 + index * 5)m").font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.62))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Museum.surface.opacity(0.86), in: Capsule())
                        .overlay(Capsule().stroke(Museum.borderStrong, lineWidth: 1))
                    }
                }
                .buttonStyle(.plain)
                .position(markerPoint(index, in: proxy.size))
            }
        }
    }

    private func markerPoint(_ index: Int, in size: CGSize) -> CGPoint {
        let points = [CGPoint(x: size.width * 0.30, y: size.height * 0.36), CGPoint(x: size.width * 0.66, y: size.height * 0.28), CGPoint(x: size.width * 0.54, y: size.height * 0.52)]
        return points[index % points.count]
    }
}

struct PulseRing: View {
    let delay: Double
    @State private var pulse = false

    var body: some View {
        Circle()
            .stroke(Museum.blue.opacity(pulse ? 0 : 0.65), lineWidth: 1)
            .background(Circle().fill(Museum.blue.opacity(pulse ? 0 : 0.20)))
            .frame(width: pulse ? 76 : 46, height: pulse ? 76 : 46)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false).delay(delay), value: pulse)
            .onAppear { pulse = true }
    }
}
