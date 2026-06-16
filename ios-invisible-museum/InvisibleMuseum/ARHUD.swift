import SwiftUI

struct ARHUD: View {
    let space: MuseumSpace
    let onExit: () -> Void

    var body: some View {
        VStack {
            topBar
            Spacer()
            HStack { radar; Spacer() }
            bottomHint
        }
        .padding(.horizontal, Museum.Spacing.pageHorizontal)
        .padding(.top, 54)
        .padding(.bottom, 28)
    }

    private var topBar: some View {
        HStack {
            Label(space.name, systemImage: "location.north.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.black.opacity(0.44), in: Capsule())
                .overlay(Capsule().stroke(Museum.borderStrong, lineWidth: 1))
            Spacer()
            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.44), in: Circle())
                    .overlay(Circle().stroke(Museum.borderStrong, lineWidth: 1))
            }
        }
    }

    private var radar: some View {
        ZStack {
            Circle().fill(.black.opacity(0.44))
            Circle().stroke(Museum.borderStrong, lineWidth: 1)
            Circle().stroke(Museum.blue.opacity(0.42), lineWidth: 1).frame(width: 48, height: 48)
            Rectangle().fill(LinearGradient(colors: [Museum.blue.opacity(0.46), .clear], startPoint: .top, endPoint: .bottom)).frame(width: 1, height: 70)
            Circle().fill(Museum.blue).frame(width: 7, height: 7).blueGlow(0.85)
            Circle().fill(.white.opacity(0.65)).frame(width: 4, height: 4).offset(x: 19, y: -18)
            Circle().fill(.white.opacity(0.65)).frame(width: 4, height: 4).offset(x: -16, y: 22)
        }
        .frame(width: 82, height: 82)
    }

    private var bottomHint: some View {
        Text("Move slowly to reveal nearby exhibits")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.46), in: Capsule())
            .overlay(Capsule().stroke(Museum.borderStrong, lineWidth: 1))
    }
}
