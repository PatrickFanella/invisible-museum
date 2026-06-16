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
    private(set) var spaces: [MuseumSpace]
    private(set) var nearbySpacesState: NearbySpacesState = .loading
    var savedExhibitIDs: Set<String> = []
    var downloadedSpaceIDs: Set<String>


    enum NearbySpacesState: Equatable {
        case loading
        case loadedFromBackend
        case sampleFallback(reason: String)
    }


    init(repository: any MuseumRepository = BackendMuseumRepository()) {
        self.repository = repository
        spaces = SampleData.spaces
        downloadedSpaceIDs = Set(SampleData.spaces.filter(\.isDownloaded).map(\.id))
    }


    func space(id: String) -> MuseumSpace? {
        spaces.first { $0.id == id }
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
    }


    func isDownloaded(_ space: MuseumSpace) -> Bool {
        downloadedSpaceIDs.contains(space.id)
    }


    func toggleDownloaded(_ space: MuseumSpace) {
        if downloadedSpaceIDs.contains(space.id) {
            downloadedSpaceIDs.remove(space.id)
        } else {
            downloadedSpaceIDs.insert(space.id)
        }
    }


    func loadNearbySpaces() async {
        nearbySpacesState = .loading

        do {
            let fetchedSpaces = try await repository.fetchNearbySpaces(latitude: 41.794, longitude: -88.007, radiusMeters: 5000)
            spaces = fetchedSpaces
            downloadedSpaceIDs = Set(fetchedSpaces.filter(\.isDownloaded).map(\.id))
            nearbySpacesState = .loadedFromBackend
        } catch {
            spaces = SampleData.spaces
            downloadedSpaceIDs = Set(SampleData.spaces.filter(\.isDownloaded).map(\.id))
            nearbySpacesState = .sampleFallback(reason: fallbackReason(for: error))
        }
    }

    func submitContribution(spaceID: String, suggestedTitle: String, kind: ExhibitKind, body: String, contributorName: String) async throws -> ContributionSubmissionDTO {
        try await repository.submitContribution(
            spaceID: spaceID,
            suggestedTitle: suggestedTitle,
            kind: kind,
            body: body,
            contributorName: contributorName
        )
    }


    var savedExhibits: [(space: MuseumSpace, exhibit: Exhibit)] {
        spaces.flatMap { space in
            space.exhibits
                .filter { savedExhibitIDs.contains($0.id) }
                .map { (space, $0) }
        }
    }


    private func fallbackReason(for error: Error) -> String {
        switch error {
        case MuseumAPIClient.APIError.backendUnavailable:
            return "Backend unavailable"
        case MuseumAPIClient.APIError.invalidResponse:
            return "Bad backend response"
        case MuseumAPIClient.APIError.unexpectedStatusCode(let statusCode):
            return "Server \(statusCode)"
        case MuseumAPIClient.APIError.validationFailed:
            return "Backend rejected the request"
        default:
            return "Showing sample spaces"
        }
    }
}
