import AppKit
import CoreImage
import Metal
import MetalKit
import SwiftUI

struct MetalImagePreviewView: NSViewRepresentable {
    let imageURL: URL

    static var isAvailable: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(imageURL: imageURL)
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.autoResizeDrawable = true
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = Self.clearColor
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.update(imageURL: imageURL)
        view.setNeedsDisplay(view.bounds)
    }

    static func dismantleNSView(_ nsView: MTKView, coordinator _: Coordinator) {
        nsView.delegate = nil
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        private var imageURL: URL
        private var image: CIImage?
        private var context: CIContext?
        private var commandQueue: MTLCommandQueue?
        private var clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        private weak var view: MTKView?

        init(imageURL: URL) {
            self.imageURL = imageURL
            super.init()
        }

        @MainActor
        func attach(to view: MTKView) {
            self.view = view
            clearColor = MetalImagePreviewView.clearColor
            if let device = view.device {
                context = CIContext(mtlDevice: device)
                commandQueue = device.makeCommandQueue()
            }
            loadImage()
            view.delegate = self
            view.needsDisplay = true
        }

        @MainActor
        func update(imageURL: URL) {
            guard imageURL.standardizedFileURL != self.imageURL.standardizedFileURL else { return }
            self.imageURL = imageURL
            loadImage()
            view?.needsDisplay = true
        }

        func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let image,
                  let context,
                  let commandBuffer = commandQueue?.makeCommandBuffer() else {
                return
            }

            clear(drawable: drawable, commandBuffer: commandBuffer)
            let drawableSize = CGSize(width: drawable.texture.width, height: drawable.texture.height)
            guard drawableSize.width > 0, drawableSize.height > 0 else { return }

            let outputImage = Self.aspectFit(image: image, in: drawableSize)
            context.render(
                outputImage,
                to: drawable.texture,
                commandBuffer: commandBuffer,
                bounds: CGRect(origin: .zero, size: drawableSize),
                colorSpace: Self.displayColorSpace
            )
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        private func loadImage() {
            image = CIImage(contentsOf: imageURL, options: [.applyOrientationProperty: true])
        }

        private func clear(drawable: CAMetalDrawable, commandBuffer: MTLCommandBuffer) {
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = drawable.texture
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].storeAction = .store
            descriptor.colorAttachments[0].clearColor = clearColor
            commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)?.endEncoding()
        }

        private static func aspectFit(image: CIImage, in drawableSize: CGSize) -> CIImage {
            let extent = image.extent
            guard extent.width > 0, extent.height > 0 else { return image }

            let scale = min(drawableSize.width / extent.width, drawableSize.height / extent.height)
            let outputWidth = extent.width * scale
            let outputHeight = extent.height * scale
            let x = (drawableSize.width - outputWidth) / 2
            let y = (drawableSize.height - outputHeight) / 2

            let normalized = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            let scaled = normalized.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            return scaled.transformed(by: CGAffineTransform(translationX: x, y: y))
        }

        private static let displayColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }

    private static var clearColor: MTLClearColor {
        let color = NSColor.textBackgroundColor.usingColorSpace(.deviceRGB) ?? .textBackgroundColor
        return MTLClearColor(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )
    }
}
