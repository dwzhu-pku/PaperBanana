import AppKit
import SwiftUI

@MainActor
final class AppIconController {
    static let shared = AppIconController()

    private var currentScheme: ColorScheme?

    private init() {}

    func apply(colorScheme: ColorScheme) {
        guard currentScheme != colorScheme else { return }
        currentScheme = colorScheme

        let resourceName = colorScheme == .dark ? "PaperBananaIconDark" : "PaperBananaIconLight"
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url)
        else {
            return
        }
        image.size = NSSize(width: 128, height: 128)
        NSApp.applicationIconImage = image
    }
}
