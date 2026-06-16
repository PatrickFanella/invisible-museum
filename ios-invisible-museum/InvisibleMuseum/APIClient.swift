import Foundation

enum BackendConfiguration {
    static let apiBaseURLDefaultsKey = "InvisibleMuseum.apiBaseURL"
    static let apiBaseURLEnvironmentKey = "InvisibleMuseum.apiBaseURL"
    static let apiBaseURLInfoPlistKey = "InvisibleMuseum.apiBaseURL"
    static let defaultBaseURL = URL(string: "http://localhost:8080")!

    static var baseURL: URL { resolvedConfiguration().url }

    static var displayBaseURL: String {
        baseURL.absoluteString
    }

    static var sourceDescription: String {
        resolvedConfiguration().source
    }

    private static func resolvedConfiguration() -> (url: URL, source: String) {
        if let configuredURL = url(from: UserDefaults.standard.string(forKey: apiBaseURLDefaultsKey)) {
            return (configuredURL, "UserDefaults")
        }

        if let configuredURL = url(from: ProcessInfo.processInfo.environment[apiBaseURLEnvironmentKey]) {
            return (configuredURL, "Environment")
        }

        if let configuredURL = url(from: Bundle.main.object(forInfoDictionaryKey: apiBaseURLInfoPlistKey) as? String) {
            return (configuredURL, "Info.plist")
        }

        return (defaultBaseURL, "Default")
    }

    private static func url(from rawValue: String?) -> URL? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else { return nil }
        return URL(string: rawValue)
    }
}

struct MuseumAPIClient {
    enum APIError: Error {
        case invalidResponse
        case unexpectedStatusCode(Int)
        case backendUnavailable
        case validationFailed
    }

    var baseURL: URL = BackendConfiguration.baseURL
    var session: URLSession = .shared
    var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }()

    func fetchNearbySpaces(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [MuseumSpaceDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/spaces/nearby"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lng", value: String(longitude)),
            URLQueryItem(name: "radius_m", value: String(Int(radiusMeters)))
        ]

        guard let url = components?.url else { throw APIError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else { throw APIError.unexpectedStatusCode(httpResponse.statusCode) }

        return try decoder.decode([MuseumSpaceDTO].self, from: data)
    }

    func submitContribution(spaceID: String, suggestedTitle: String, kind: ExhibitKind, body: String, contributorName: String) async throws -> ContributionSubmissionDTO {
        let url = baseURL.appendingPathComponent("api/v1/contributions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(ContributionSubmissionRequest(
            spaceID: spaceID,
            suggestedTitle: suggestedTitle,
            kind: kind,
            body: body,
            contributorName: contributorName
        ))

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }

            switch httpResponse.statusCode {
            case 200...299:
                let submission = try decoder.decode(ContributionSubmissionDTO.self, from: data)
                guard submission.status == .pending else { throw APIError.invalidResponse }
                return submission
            case 400, 401, 403, 409, 422:
                throw APIError.validationFailed
            case 500...599:
                throw APIError.backendUnavailable
            default:
                throw APIError.unexpectedStatusCode(httpResponse.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.backendUnavailable
        }
    }

    func fetchModerationQueue(status: ContributionModerationStatus = .pending) async throws -> [ContributionModerationItemDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/admin/contributions"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "status", value: status.rawValue)]

        guard let url = components?.url else { throw APIError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else { throw APIError.unexpectedStatusCode(httpResponse.statusCode) }

        return try decoder.decode([ContributionModerationItemDTO].self, from: data)
    }

    func updateContributionStatus(id: String, status: ContributionModerationStatus) async throws -> ContributionModerationItemDTO {
        let url = baseURL.appendingPathComponent("api/v1/admin/contributions/\(id)/status")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(ContributionModerationStatusRequest(status: status))

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }

            switch httpResponse.statusCode {
            case 200...299:
                return try decoder.decode(ContributionModerationItemDTO.self, from: data)
            case 400, 401, 403, 404, 409, 422:
                throw APIError.validationFailed
            case 500...599:
                throw APIError.backendUnavailable
            default:
                throw APIError.unexpectedStatusCode(httpResponse.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.backendUnavailable
        }
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }
}

struct MuseumSpaceDTO: Decodable {
    let id: String
    let name: String
    let tagline: String
    let summary: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
    let distanceMeters: Double
    let kind: SpaceKind
    let exhibitCount: Int
    let contributorCount: Int
    let accentHue: Double
    let isDownloaded: Bool
    let exhibits: [ExhibitDTO]

    func toModel() -> MuseumSpace {
        MuseumSpace(
            id: id,
            name: name,
            tagline: tagline,
            summary: summary,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            distanceMeters: distanceMeters,
            kind: kind,
            exhibitCount: exhibitCount,
            contributorCount: contributorCount,
            accentHue: accentHue,
            isDownloaded: isDownloaded,
            exhibits: exhibits.map { $0.toModel() }
        )
    }
}

struct ExhibitDTO: Decodable {
    let id: String
    let title: String
    let kind: ExhibitKind
    let body: String
    let year: String
    let contributor: String
    let tags: [String]
    let status: ExhibitStatus
    let confidence: ExhibitConfidence
    let offset: SIMD3<Float>
    let durationSeconds: Int?
    let likes: Int

    private enum CodingKeys: String, CodingKey {
        case id, title, kind, body, year, contributor, tags, status, confidence, offset, durationSeconds, likes
    }

    private struct OffsetVector: Decodable {
        let x: Float
        let y: Float
        let z: Float

        var simd: SIMD3<Float> { SIMD3<Float>(x, y, z) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        kind = try container.decode(ExhibitKind.self, forKey: .kind)
        body = try container.decode(String.self, forKey: .body)
        year = try container.decode(String.self, forKey: .year)
        contributor = try container.decode(String.self, forKey: .contributor)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        status = try container.decode(ExhibitStatus.self, forKey: .status)
        confidence = try container.decode(ExhibitConfidence.self, forKey: .confidence)
        offset = Self.decodeOffset(from: container)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0
    }

    func toModel() -> Exhibit {
        Exhibit(
            id: id,
            title: title,
            kind: kind,
            body: body,
            year: year,
            contributor: contributor,
            tags: tags,
            status: status,
            confidence: confidence,
            offset: offset,
            durationSeconds: durationSeconds,
            likes: likes
        )
    }

    private static func decodeOffset(from container: KeyedDecodingContainer<CodingKeys>) -> SIMD3<Float> {
        if let values = try? container.decode([Float].self, forKey: .offset), values.count == 3 {
            return SIMD3<Float>(values[0], values[1], values[2])
        }

        if let values = try? container.decode([Double].self, forKey: .offset), values.count == 3 {
            return SIMD3<Float>(Float(values[0]), Float(values[1]), Float(values[2]))
        }

        if let vector = try? container.decode(OffsetVector.self, forKey: .offset) {
            return vector.simd
        }

        return .zero
    }
}

struct ContributionSubmissionDTO: Decodable {
    enum Status: String, Decodable {
        case pending
    }

    let id: String
    let status: Status
}

struct ContributionModerationItemDTO: Decodable {
    let id: String
    let spaceID: String?
    let suggestedTitle: String
    let kind: ExhibitKind
    let body: String
    let contributorName: String
    let status: ContributionModerationStatus
    let createdAt: String
    let updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case spaceID = "space_id"
        case suggestedTitle = "suggested_title"
        case kind
        case body
        case contributorName = "contributor_name"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toModel() -> ContributionModerationItem {
        ContributionModerationItem(
            id: id,
            spaceID: spaceID,
            suggestedTitle: suggestedTitle,
            kind: kind,
            body: body,
            contributorName: contributorName,
            status: status,
            createdAt: Self.parseDate(createdAt),
            updatedAt: Self.parseDate(updatedAt)
        )
    }

    private static func parseDate(_ value: String) -> Date {
        if let date = ISO8601DateFormatter.improved.date(from: value) {
            return date
        }
        return .now
    }
}

private struct ContributionModerationStatusRequest: Encodable {
    let status: ContributionModerationStatus
}

private extension ISO8601DateFormatter {
    static let improved: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct ContributionSubmissionRequest: Encodable {
    let spaceID: String
    let suggestedTitle: String
    let kind: ExhibitKind
    let body: String
    let contributorName: String

    private enum CodingKeys: String, CodingKey {
        case spaceID = "space_id"
        case suggestedTitle = "suggested_title"
        case kind
        case body
        case contributorName = "contributor_name"
    }
}
