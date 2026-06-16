import Foundation
import SwiftUI

struct MuseumSpace: Identifiable, Codable, Hashable, Sendable {
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
    let exhibits: [Exhibit]

    var accent: Color { Museum.accent(for: accentHue) }
}

enum SpaceKind: String, Codable, Sendable, CaseIterable {
    case plaza, station, storefront, ruin, garden, hall

    var label: String {
        switch self {
        case .plaza: "Public Plaza"
        case .station: "Transit Hall"
        case .storefront: "Storefront"
        case .ruin: "Ruin"
        case .garden: "Garden"
        case .hall: "Civic Hall"
        }
    }

    var symbol: String {
        switch self {
        case .plaza: "building.columns"
        case .station: "tram.fill"
        case .storefront: "storefront"
        case .ruin: "building.2.crop.circle"
        case .garden: "leaf.fill"
        case .hall: "theatermasks.fill"
        }
    }
}

struct Exhibit: Identifiable, Codable, Hashable, Sendable {
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
}

enum ExhibitKind: String, Codable, Sendable, CaseIterable {
    case story, image, audio, artifact, timeline, thread

    var label: String {
        switch self {
        case .story: "Narrative"
        case .image: "Visual Archive"
        case .audio: "Audio Narrative"
        case .artifact: "3D Object"
        case .timeline: "Timeline"
        case .thread: "Community Thread"
        }
    }

    var symbol: String {
        switch self {
        case .story: "text.quote"
        case .image: "photo"
        case .audio: "waveform"
        case .artifact: "cube.transparent"
        case .timeline: "point.topleft.down.curvedto.point.bottomright.up"
        case .thread: "bubble.left.and.bubble.right"
        }
    }
}

enum ExhibitStatus: String, Codable, Sendable { case published, underReview }
enum ExhibitConfidence: String, Codable, Sendable { case high, medium, low }

enum ContributionModerationStatus: String, Codable, Sendable, CaseIterable {
    case pending, approved, rejected

    var label: String {
        switch self {
        case .pending: "Pending"
        case .approved: "Approved"
        case .rejected: "Rejected"
        }
    }
}

struct ContributionModerationItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let spaceID: String?
    let suggestedTitle: String
    let kind: ExhibitKind
    let body: String
    let contributorName: String
    let status: ContributionModerationStatus
    let createdAt: Date
    let updatedAt: Date
}
