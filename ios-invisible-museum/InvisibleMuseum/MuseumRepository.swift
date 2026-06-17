import Foundation

protocol MuseumRepository {
    var requiresAdminBearerToken: Bool { get }
    func fetchNearbySpaces(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [MuseumSpace]
    func fetchTours() async throws -> [WalkingTour]
    func fetchTour(id: String) async throws -> WalkingTour
    func submitContribution(spaceID: String, suggestedTitle: String, kind: ExhibitKind, body: String, contributorName: String) async throws -> ContributionSubmissionDTO
    func fetchModerationQueue() async throws -> [ContributionModerationItem]
    func updateContributionStatus(id: String, status: ContributionModerationStatus) async throws -> ContributionModerationItem
}

struct BackendMuseumRepository: MuseumRepository {
    var client: MuseumAPIClient = MuseumAPIClient()
    var requiresAdminBearerToken: Bool { true }

    func fetchNearbySpaces(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [MuseumSpace] {
        let spaces = try await client.fetchNearbySpaces(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)
        return spaces.map { $0.toModel() }
    }

    func fetchTours() async throws -> [WalkingTour] {
        try await client.fetchTours()
    }

    func fetchTour(id: String) async throws -> WalkingTour {
        try await client.fetchTour(id: id)
    }

    func submitContribution(spaceID: String, suggestedTitle: String, kind: ExhibitKind, body: String, contributorName: String) async throws -> ContributionSubmissionDTO {
        try await client.submitContribution(
            spaceID: spaceID,
            suggestedTitle: suggestedTitle,
            kind: kind,
            body: body,
            contributorName: contributorName
        )
    }

    func fetchModerationQueue() async throws -> [ContributionModerationItem] {
        let items = try await client.fetchModerationQueue()
        return items.map { $0.toModel() }
    }

    func updateContributionStatus(id: String, status: ContributionModerationStatus) async throws -> ContributionModerationItem {
        let item = try await client.updateContributionStatus(id: id, status: status)
        return item.toModel()
    }
}

struct SampleMuseumRepository: MuseumRepository {
    var requiresAdminBearerToken: Bool { false }

    func fetchNearbySpaces(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [MuseumSpace] {
        SampleData.spaces
    }

    func fetchTours() async throws -> [WalkingTour] {
        [SampleTours.downtownLoop]
    }

    func fetchTour(id: String) async throws -> WalkingTour {
        guard id == SampleTours.downtownLoop.id else {
            throw MuseumAPIClient.APIError.unexpectedStatusCode(404)
        }
        return SampleTours.downtownLoop
    }

    func submitContribution(spaceID: String, suggestedTitle: String, kind: ExhibitKind, body: String, contributorName: String) async throws -> ContributionSubmissionDTO {
        throw MuseumAPIClient.APIError.backendUnavailable
    }

    func fetchModerationQueue() async throws -> [ContributionModerationItem] {
        SampleData.moderationQueue
    }

    func updateContributionStatus(id: String, status: ContributionModerationStatus) async throws -> ContributionModerationItem {
        guard let item = SampleData.moderationQueue.first(where: { $0.id == id }) else {
            throw MuseumAPIClient.APIError.validationFailed
        }
        return ContributionModerationItem(
            id: item.id,
            spaceID: item.spaceID,
            suggestedTitle: item.suggestedTitle,
            kind: item.kind,
            body: item.body,
            contributorName: item.contributorName,
            status: status,
            createdAt: item.createdAt,
            updatedAt: Date()
        )
    }
}
