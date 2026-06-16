import Foundation

protocol MuseumRepository {
    func fetchNearbySpaces(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [MuseumSpace]
    func submitContribution(spaceID: String, suggestedTitle: String, kind: ExhibitKind, body: String, contributorName: String) async throws -> ContributionSubmissionDTO
}

struct BackendMuseumRepository: MuseumRepository {
    var client: MuseumAPIClient = MuseumAPIClient()

    func fetchNearbySpaces(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [MuseumSpace] {
        let spaces = try await client.fetchNearbySpaces(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)
        return spaces.map { $0.toModel() }
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
}

struct SampleMuseumRepository: MuseumRepository {
    func fetchNearbySpaces(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [MuseumSpace] {
        SampleData.spaces
    }

    func submitContribution(spaceID: String, suggestedTitle: String, kind: ExhibitKind, body: String, contributorName: String) async throws -> ContributionSubmissionDTO {
        throw MuseumAPIClient.APIError.backendUnavailable
    }
}
