//
//  MuseumStore.swift
//  InvisibleMuseum
//
//  Lightweight observable app state. In production this is backed by the REST
//  client + local cache; here it serves seed content and tracks local-only
//  state such as saved exhibits and downloaded spaces.
//


import Foundation
import Observation


@MainActor
@Observable
final class MuseumStore {
    private let repository: any MuseumRepository
    private let persistence: MuseumLocalPersistence
    private(set) var spaces: [MuseumSpace]
    private(set) var tours: [WalkingTour]
    private(set) var nearbySpacesState: NearbySpacesState = .loading
    private(set) var toursState: ToursState = .loading
    private(set) var moderationQueue: [ContributionModerationItem] = []
    private(set) var moderationQueueState: ModerationQueueState = .loading
    private(set) var moderationMessage: String?
    var savedExhibitIDs: Set<String> = []
    var downloadedSpaceIDs: Set<String>
    private var downloadedSpaceOverrides: [String: Bool] = [:]
    private(set) var contributionCount: Int = 0


    enum NearbySpacesState: Equatable {
        case loading
        case loadedFromBackend
        case sampleFallback(reason: String)
    }

    enum ToursState: Equatable {
        case loading
        case loadedFromBackend
        case sampleFallback(reason: String)
    }

    enum ModerationQueueState: Equatable {
        case loading
        case loadedFromBackend
        case adminTokenRequired
        case adminTokenInvalid
        case adminAuthNotConfigured
        case sampleFallback(reason: String)
    }


    init(repository: any MuseumRepository = BackendMuseumRepository(), persistence: MuseumLocalPersistence = .init()) {
        self.repository = repository
        self.persistence = persistence
        spaces = SampleData.spaces
        tours = [SampleTours.downtownLoop]
        let savedIDs = persistence.loadSavedExhibitIDs()
        let overrides = persistence.loadDownloadedSpaceOverrides()
        let contributionTotal = persistence.loadContributionCount()

        let sampleDownloadedIDs = Set(SampleData.spaces.filter(\.isDownloaded).map(\.id))
        let resolvedDownloadedIDs: Set<String>
        if let persistedDownloadedIDs = persistence.loadDownloadedSpaceIDs() {
            resolvedDownloadedIDs = persistedDownloadedIDs
        } else {
            resolvedDownloadedIDs = Self.resolveDownloadedIDs(defaultIDs: sampleDownloadedIDs, overrides: overrides)
            persistence.saveDownloadedSpaceIDs(resolvedDownloadedIDs)
        }

        savedExhibitIDs = savedIDs
        downloadedSpaceOverrides = overrides
        contributionCount = contributionTotal
        downloadedSpaceIDs = resolvedDownloadedIDs

    }


    func space(id: String) -> MuseumSpace? {
        spaces.first { $0.id == id }
    }


    func tour(id: String) -> WalkingTour? {
        tours.first { $0.id == id }
    }


    func isSaved(_ exhibit: Exhibit) -> Bool {
        savedExhibitIDs.contains(exhibit.id)
    }


    func toggleSaved(_ exhibit: Exhibit) {
        if savedExhibitIDs.contains(exhibit.id) {
            savedExhibitIDs.remove(exhibit.id)
        } else {
            savedExhibitIDs.insert(exhibit.id)
        }

        persistence.saveSavedExhibitIDs(savedExhibitIDs)
    }


    func isDownloaded(_ space: MuseumSpace) -> Bool {
        downloadedSpaceIDs.contains(space.id)
    }


    func toggleDownloaded(_ space: MuseumSpace) {
        if downloadedSpaceIDs.contains(space.id) {
            downloadedSpaceIDs.remove(space.id)
            downloadedSpaceOverrides[space.id] = false
        } else {
            downloadedSpaceIDs.insert(space.id)
            downloadedSpaceOverrides[space.id] = true
        }

        persistence.saveDownloadedSpaceIDs(downloadedSpaceIDs)
        persistence.saveDownloadedSpaceOverrides(downloadedSpaceOverrides)
    }


    func loadNearbySpaces() async {
        nearbySpacesState = .loading

        do {
            let fetchedSpaces = try await repository.fetchNearbySpaces(latitude: 41.794, longitude: -88.007, radiusMeters: 5000)
            spaces = fetchedSpaces
            downloadedSpaceIDs = Self.resolveDownloadedIDs(
                defaultIDs: Set(fetchedSpaces.filter(\.isDownloaded).map(\.id)),
                overrides: downloadedSpaceOverrides
            )
            persistence.saveDownloadedSpaceIDs(downloadedSpaceIDs)
            nearbySpacesState = .loadedFromBackend
        } catch {
            spaces = SampleData.spaces
            downloadedSpaceIDs = Self.resolveDownloadedIDs(
                defaultIDs: Set(SampleData.spaces.filter(\.isDownloaded).map(\.id)),
                overrides: downloadedSpaceOverrides
            )
            persistence.saveDownloadedSpaceIDs(downloadedSpaceIDs)
            nearbySpacesState = .sampleFallback(reason: fallbackReason(for: error))
        }
    }

    func loadTours() async {
        toursState = .loading

        do {
            let fetchedTours = try await repository.fetchTours()
            tours = fetchedTours.isEmpty ? [SampleTours.downtownLoop] : fetchedTours
            toursState = fetchedTours.isEmpty ? .sampleFallback(reason: "Backend returned no tours") : .loadedFromBackend
        } catch {
            tours = [SampleTours.downtownLoop]
            toursState = .sampleFallback(reason: fallbackReason(for: error))
        }
    }

    func submitContribution(spaceID: String, suggestedTitle: String, kind: ExhibitKind, body: String, contributorName: String) async throws -> ContributionSubmissionDTO {
        let submission = try await repository.submitContribution(
            spaceID: spaceID,
            suggestedTitle: suggestedTitle,
            kind: kind,
            body: body,
            contributorName: contributorName
        )

        contributionCount += 1
        persistence.saveContributionCount(contributionCount)
        return submission
    }

    func loadModerationQueue() async {
        moderationQueueState = .loading
        moderationMessage = nil

        if repository.requiresAdminBearerToken, BackendConfiguration.adminBearerToken == nil {
            moderationQueue = []
            moderationQueueState = .adminTokenRequired
            moderationMessage = "Set an admin token in Profile to load the moderation queue."
            return
        }

        do {
            let fetched = try await repository.fetchModerationQueue()
            moderationQueue = fetched.filter { $0.status == .pending }
            moderationQueueState = .loadedFromBackend
        } catch {
            if case MuseumAPIClient.APIError.adminUnauthorized = error {
                moderationQueue = []
                moderationQueueState = .adminTokenInvalid
                moderationMessage = "Admin token was rejected by the backend."
                return
            }
            if case MuseumAPIClient.APIError.adminAuthNotConfigured = error {
                moderationQueue = []
                moderationQueueState = .adminAuthNotConfigured
                moderationMessage = "Backend admin auth is not configured yet."
                return
            }
            moderationQueue = SampleData.moderationQueue.filter { $0.status == .pending }
            moderationQueueState = .sampleFallback(reason: fallbackReason(for: error))
        }
    }

    func reviewContribution(id: String, status: ContributionModerationStatus) async {
        if repository.requiresAdminBearerToken, BackendConfiguration.adminBearerToken == nil {
            moderationQueueState = .adminTokenRequired
            moderationMessage = "Set an admin token in Profile to review contributions."
            return
        }

        do {
            let updated = try await repository.updateContributionStatus(id: id, status: status)
            moderationQueue.removeAll { $0.id == updated.id }
            moderationMessage = "Updated \(updated.suggestedTitle) to \(status.label.lowercased())."
        } catch {
            if case MuseumAPIClient.APIError.adminUnauthorized = error {
                moderationQueueState = .adminTokenInvalid
                moderationMessage = "Admin token was rejected by the backend."
                return
            }
            if case MuseumAPIClient.APIError.adminAuthNotConfigured = error {
                moderationQueueState = .adminAuthNotConfigured
                moderationMessage = "Backend admin auth is not configured yet."
                return
            }
            if case .sampleFallback = moderationQueueState {
                moderationQueue.removeAll { $0.id == id }
                moderationMessage = "Saved locally only. \(fallbackReason(for: error))."
                return
            }
            moderationMessage = fallbackReason(for: error)
        }
    }


    var savedExhibits: [(space: MuseumSpace, exhibit: Exhibit)] {
        spaces.flatMap { space in
            space.exhibits
                .filter { savedExhibitIDs.contains($0.id) }
                .map { (space, $0) }
        }
    }


    private static func resolveDownloadedIDs(defaultIDs: Set<String>, overrides: [String: Bool]) -> Set<String> {
        var resolved = defaultIDs

        for (id, isDownloaded) in overrides {
            if isDownloaded {
                resolved.insert(id)
            } else {
                resolved.remove(id)
            }
        }

        return resolved
    }


    private func fallbackReason(for error: Error) -> String {
        switch error {
        case MuseumAPIClient.APIError.backendUnavailable:
            return "Backend unavailable"
        case MuseumAPIClient.APIError.invalidResponse:
            return "Bad backend response"
        case MuseumAPIClient.APIError.adminAuthNotConfigured:
            return "Backend admin auth is not configured"
        case MuseumAPIClient.APIError.adminUnauthorized:
            return "Admin token rejected"
        case MuseumAPIClient.APIError.unexpectedStatusCode(let statusCode) where statusCode == 404:
            return "Contribution not found"
        case MuseumAPIClient.APIError.unexpectedStatusCode(let statusCode):
            return "Server \(statusCode)"
        case MuseumAPIClient.APIError.validationFailed:
            return "Backend rejected the request"
        default:
            return "Showing sample spaces"
        }
    }
}
