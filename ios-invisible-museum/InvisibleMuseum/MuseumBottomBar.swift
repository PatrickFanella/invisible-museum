import SwiftUI

struct MuseumBottomBar: View {
    @Binding var selection: MuseumTab

    var body: some View {
        HStack(spacing: 8) {
            tabButton(.explore, icon: "map.fill")
            tabButton(.contribute, icon: "plus.bubble.fill")
            tabButton(.saved, icon: "heart.fill")
        }
        .padding(8)
        .background(.black.opacity(0.78), in: Capsule())
        .overlay(Capsule().stroke(Museum.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 10)
        .padding(.horizontal, Museum.Spacing.pageHorizontal)
        .padding(.vertical, 8)
    }

    private func tabButton(_ item: MuseumTab, icon: String) -> some View {
        Button {
            withAnimation(.snappy) {
                selection = item
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                if selection == item {
                    Text(item.rawValue)
                }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(selection == item ? .black : Color.white.opacity(0.62))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, selection == item ? 14 : 12)
            .background(selection == item ? Museum.blue : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension MuseumTab {
    var iconName: String {
        switch self {
        case .explore: "map.fill"
        case .contribute: "plus.bubble.fill"
        case .saved: "heart.fill"
        }
    }
}
