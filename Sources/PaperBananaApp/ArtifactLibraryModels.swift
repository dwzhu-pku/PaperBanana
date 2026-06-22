import Foundation

enum ArtifactKind: String, CaseIterable, Identifiable {
    case image
    case archive
    case data
    case document

    var id: String { rawValue }

    var label: String {
        switch self {
        case .image: "Image"
        case .archive: "Archive"
        case .data: "Data"
        case .document: "Document"
        }
    }

    var systemImage: String {
        switch self {
        case .image: "photo"
        case .archive: "archivebox"
        case .data: "doc.text"
        case .document: "doc.richtext"
        }
    }
}

enum ArtifactRunStatus: String, CaseIterable, Identifiable {
    case completed
    case running
    case timedOut
    case stalled
    case cancelled
    case failed
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .completed: "Completed"
        case .running: "Running"
        case .timedOut: "Timed out"
        case .stalled: "Stalled"
        case .cancelled: "Cancelled"
        case .failed: "Failed"
        case .unknown: "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .completed: "checkmark.circle"
        case .running: "clock"
        case .timedOut: "timer"
        case .stalled: "exclamationmark.triangle"
        case .cancelled: "xmark.circle"
        case .failed: "xmark.octagon"
        case .unknown: "questionmark.circle"
        }
    }

    var needsAttention: Bool {
        switch self {
        case .completed, .running:
            return false
        case .timedOut, .stalled, .cancelled, .failed, .unknown:
            return true
        }
    }
}

struct PaperBananaArtifact: Identifiable, Hashable {
    let id: String
    let url: URL
    let kind: ArtifactKind
    let title: String
    let workflow: String
    let relativePath: String
    let modifiedAt: Date
    let byteCount: Int64
    let promptURL: URL?
    let logURL: URL?
    let metadataURL: URL?
    let runID: String
    let runDirectoryURL: URL?
    let runStatus: ArtifactRunStatus?

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    var refinementLineage: ArtifactLineage? {
        guard let metadataURL else { return nil }
        return ArtifactLineage(metadataURL: metadataURL)
    }

    var wasNativeRefined: Bool {
        refinementLineage?.workflow == "native_refine"
    }

    var isRecovered: Bool {
        workflow == "recovered" || relativePath.hasPrefix("recovered/")
    }
}
