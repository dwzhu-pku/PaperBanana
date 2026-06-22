import Foundation
import ImageIO
import Metal

struct PaperBananaImageQualityReport: Equatable {
    let pixelWidth: Int
    let pixelHeight: Int
    let usesMetalDevice: Bool
    let warnings: [String]

    var resolutionText: String {
        "\(pixelWidth)x\(pixelHeight)"
    }

    var megapixelsText: String {
        let megapixels = Double(pixelWidth * pixelHeight) / 1_000_000
        return String(format: "%.1f MP", megapixels)
    }

    func targetWarnings(for requestedResolution: String) -> [String] {
        guard let target = PaperBananaResolutionTarget(requestedResolution: requestedResolution) else {
            return []
        }

        let longEdge = max(pixelWidth, pixelHeight)
        let pixelCount = pixelWidth * pixelHeight
        var targetWarnings: [String] = []
        if longEdge < target.minimumLongEdge {
            targetWarnings.append(
                "\(target.label) target expects long edge >= \(target.minimumLongEdge) px; actual is \(longEdge) px."
            )
        }
        if pixelCount < target.minimumPixelCount {
            targetWarnings.append(
                "\(target.label) target expects at least \(target.minimumMegapixelsText); actual is \(megapixelsText)."
            )
        }
        return targetWarnings
    }
}

enum PaperBananaImageQualityInspector {
    static func inspect(_ url: URL) -> PaperBananaImageQualityReport? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0,
              height > 0 else {
            return nil
        }

        var warnings: [String] = []
        if min(width, height) < 1_000 {
            warnings.append("Shortest edge is under 1K.")
        }
        if width * height < 4_000_000 {
            warnings.append("Image is below 4 megapixels.")
        }

        return PaperBananaImageQualityReport(
            pixelWidth: width,
            pixelHeight: height,
            usesMetalDevice: MTLCreateSystemDefaultDevice() != nil,
            warnings: warnings
        )
    }
}

private struct PaperBananaResolutionTarget {
    let label: String
    let minimumLongEdge: Int
    let minimumPixelCount: Int

    init?(requestedResolution: String) {
        let normalized = requestedResolution
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
        guard normalized.isEmpty == false else { return nil }

        if normalized.contains("4K") {
            label = "4K"
            minimumLongEdge = 3_000
            minimumPixelCount = 6_000_000
        } else if normalized.contains("2K") {
            label = "2K"
            minimumLongEdge = 1_800
            minimumPixelCount = 2_000_000
        } else if normalized.contains("1K") {
            label = "1K"
            minimumLongEdge = 1_000
            minimumPixelCount = 500_000
        } else {
            return nil
        }
    }

    var minimumMegapixelsText: String {
        String(format: "%.1f MP", Double(minimumPixelCount) / 1_000_000)
    }
}
