import Foundation

struct MuseumLocalPersistence {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let savedExhibitIDs = "MuseumStore.savedExhibitIDs"
        static let downloadedSpaceIDs = "MuseumStore.downloadedSpaceIDs"
        static let downloadedSpaceOverrides = "MuseumStore.downloadedSpaceOverrides"
        static let contributionCount = "MuseumStore.contributionCount"
        static let walkingTourProgressPrefix = "MuseumStore.walkingTourProgress."
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

    func loadWalkingTourProgress(tourID: String) -> WalkingTourProgress? {
        guard let data = defaults.data(forKey: Key.walkingTourProgressPrefix + tourID) else { return nil }
        return try? decoder.decode(WalkingTourProgress.self, from: data)
    }

    func saveWalkingTourProgress(_ progress: WalkingTourProgress?) {
        let key = Key.walkingTourProgressPrefix + (progress?.tourID ?? "unknown")
        guard let progress else {
            defaults.removeObject(forKey: key)
            return
        }

        if let data = try? encoder.encode(progress) {
            defaults.set(data, forKey: key)
        }
    }

    private func loadStringSet(forKey key: String) -> Set<String>? {
        guard let values = defaults.array(forKey: key) as? [String] else { return nil }
        return Set(values)
    }
}
