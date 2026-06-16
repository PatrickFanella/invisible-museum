import SwiftUI

struct ContentView: View {
    @State private var store: MuseumStore
    @State private var tab: MuseumTab = .explore

    @MainActor
    init(store: MuseumStore? = nil) {
        _store = State(initialValue: store ?? MuseumStore())
    }

    var body: some View {
        ZStack {
            Group {
                switch tab {
                case .explore: ExploreView()
                case .contribute: ContributeView()
                case .saved: SavedView(selectedTab: $tab)
                case .profile: ProfileView(selectedTab: $tab)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MuseumBottomBar(selection: $tab)
        }
        .task { await store.loadNearbySpaces() }
        .environment(store)
        .preferredColorScheme(.dark)
    }
}

enum MuseumTab: String, CaseIterable {
    case explore = "Explore"
    case contribute = "Contribute"
    case saved = "Collection"
    case profile = "Profile"
}

#Preview { ContentView(store: MuseumStore(repository: SampleMuseumRepository())) }
