import SwiftUI

struct ARHUD: View {
    let space: MuseumSpace
    let session: ARMuseumSession
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
            VStack(alignment: .leading, spacing: 4) {
                Label(space.name, systemImage: "location.north.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(topLine)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.44), in: Capsule())
            .overlay(Capsule().stroke(Museum.borderStrong, lineWidth: 1))

            Spacer()
            Text(selectedText)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.44), in: Capsule())
                .overlay(Capsule().stroke(Museum.borderStrong, lineWidth: 1))
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
        Text(statusText)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.46), in: Capsule())
            .overlay(Capsule().stroke(Museum.borderStrong, lineWidth: 1))
    }

    private var topLine: String {
        switch session.stage {
        case .requestingPermissions:
            return "Requesting location"
        case .locatingUser:
            return "Locating user"
        case .tooFar:
            return "Too far for AR"
        case .checkingGeoAvailability:
            return "Checking geo AR"
        case .localizing:
            return "Localizing geo AR"
        case .ready:
            return "AR ready"
        case .fallback:
            return "Approximate AR"
        case .denied(let reason), .unsupported(let reason):
            return reason
        }
    }

    private var selectedText: String {
        session.selectedExhibitID == nil ? "\(session.placedExhibitCount) markers" : "Selected exhibit"
    }

    private var statusText: String {
        switch session.stage {
        case .requestingPermissions:
            return "Grant location access to unlock geo AR"
        case .locatingUser:
            return "Finding your position"
        case .tooFar:
            return "Too far for AR"
        case .checkingGeoAvailability:
            return "Checking geo AR"
        case .localizing:
            return "Localizing geo AR"
        case .ready:
            return "AR ready"
        case .fallback:
            return "Approximate AR"
        case .denied(let reason), .unsupported(let reason):
            return reason
        }
    }
}
