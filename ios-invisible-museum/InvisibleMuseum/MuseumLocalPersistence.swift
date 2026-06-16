import Foundation

struct MuseumLocalPersistence {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let savedExhibitIDs = "MuseumStore.savedExhibitIDs"
        static let downloadedSpaceIDs = "MuseumStore.downloadedSpaceIDs"
        static let downloadedSpaceOverrides = "MuseumStore.downloadedSpaceOverrides"
        static let contributionCount = "MuseumStore.contributionCount"
    }

    func loadSavedExhibitIDs() -> Set<String> {
        loadStringSet(forKey: Key.savedExhibitIDs) ?? []
    }

    func saveSavedExhibitIDs(_ ids: Set<String>) {
        defaults.set(Array(ids).sorted(), forKey: Key.savedExhibitIDs)
    }

    func loadDownloadedSpaceIDs() -> Set<String>? {
        loadStringSet(forKey: Key.downloadedSpaceIDs)
    }

    func saveDownloadedSpaceIDs(_ ids: Set<String>) {
        defaults.set(Array(ids).sorted(), forKey: Key.downloadedSpaceIDs)
    }

    func loadDownloadedSpaceOverrides() -> [String: Bool] {
        defaults.dictionary(forKey: Key.downloadedSpaceOverrides) as? [String: Bool] ?? [:]
    }

    func saveDownloadedSpaceOverrides(_ overrides: [String: Bool]) {
        defaults.set(overrides, forKey: Key.downloadedSpaceOverrides)
    }

    func loadContributionCount() -> Int {
        defaults.object(forKey: Key.contributionCount) as? Int ?? 0
    }

    func saveContributionCount(_ count: Int) {
        defaults.set(count, forKey: Key.contributionCount)
    }

    private func loadStringSet(forKey key: String) -> Set<String>? {
        guard let values = defaults.array(forKey: key) as? [String] else { return nil }
        return Set(values)
    }
}
