import CoreImage
import Testing
@testable import Presenter

struct PersonMatteTests {
    private let sourceBounds = CGRect(x: 0, y: 0, width: 4, height: 2)

    @Test func blackMaskMakesBackgroundTransparent() throws {
        let source = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: sourceBounds)
        let mask = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 2, height: 1))
        let result = try #require(PersonMatte.composite(source: source, mask: mask))
        let bytes = pixels(result)
        #expect(stride(from: 3, to: bytes.count, by: 4).allSatisfy { bytes[$0] == 0 })
    }

    @Test func whiteMaskRetainsOpaqueForeground() throws {
        let source = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: sourceBounds)
        #expect(pixels(source).contains { $0 != 0 }, "Core Image could not render an unfiltered source image in this environment.")
        let mask = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 2, height: 1))
        let result = try #require(PersonMatte.composite(source: source, mask: mask))
        let bytes = pixels(result)
        #expect(stride(from: 0, to: bytes.count, by: 4).allSatisfy { bytes[$0] == 255 && bytes[$0 + 3] == 255 }, "RGBA bytes: \(bytes)")
    }

    @Test func translatedMaskAlignsWithTranslatedSource() throws {
        let bounds = CGRect(x: 10, y: 20, width: 4, height: 2)
        let source = CIImage(color: .white).cropped(to: bounds)
        let mask = CIImage(color: .white).cropped(to: CGRect(x: 3, y: 7, width: 2, height: 1))
        let result = try #require(PersonMatte.composite(source: source, mask: mask))
        #expect(result.extent == bounds)
        let bytes = pixels(result)
        #expect(stride(from: 3, to: bytes.count, by: 4).allSatisfy { bytes[$0] == 255 }, "RGBA bytes: \(bytes)")
    }

    @Test func emptyMaskDoesNotExposeRawCameraImage() {
        let source = CIImage(color: .white).cropped(to: sourceBounds)
        #expect(PersonMatte.composite(source: source, mask: .empty()) == nil)
        #expect(PersonMatte.composite(source: .empty(), mask: source) == nil)
    }

    private func pixels(_ image: CIImage) -> [UInt8] {
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = CIContext(options: [.useSoftwareRenderer: true])
        bytes.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress else { return }
            context.render(image, toBitmap: address, rowBytes: width * 4, bounds: image.extent,
                           format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        }
        return bytes
    }
}
