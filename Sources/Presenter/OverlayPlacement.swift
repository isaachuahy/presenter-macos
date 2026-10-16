import Foundation

enum OverlayShape: String, CaseIterable, Identifiable {
    case circle = "Circle"
    case rounded = "Rounded"
    case cutout = "Cutout"

    var id: String { rawValue }
}

enum OverlaySize: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    func dimensions(for shape: OverlayShape) -> CGSize {
        let width: CGFloat = switch self {
        case .small: 160
        case .medium: 224
        case .large: 320
        }
        return CGSize(width: width, height: shape == .circle ? width : width * 0.75)
    }
}

enum OverlayPlacement {
    /// Returns a finite frame contained in a visible screen, retaining the preferred center when possible.
    /// Screen rectangles use AppKit points and may have negative origins. The first screen is the fallback.
    static func frame(preferred: CGRect?, size: CGSize, screens: [CGRect]) -> CGRect {
        let available = screens.filter { isFinite($0) && $0.width > 0 && $0.height > 0 }
        let safeSize = CGSize(
            width: size.width.isFinite && size.width > 0 ? size.width : 224,
            height: size.height.isFinite && size.height > 0 ? size.height : 224
        )
        guard let first = available.first else {
            return CGRect(origin: .zero, size: safeSize)
        }
        let saved = preferred.flatMap { isFinite($0) && $0.width > 0 && $0.height > 0 ? $0 : nil }
        let screen = saved.flatMap { old in
            available.max { intersectionArea(old, $0) < intersectionArea(old, $1) }
                .flatMap { intersectionArea(old, $0) > 0 ? $0 : nil }
        } ?? first
        let fitted = CGSize(
            width: min(safeSize.width, screen.width),
            height: min(safeSize.height, screen.height)
        )
        let proposed = saved.map {
            CGPoint(x: $0.midX - fitted.width / 2, y: $0.midY - fitted.height / 2)
        } ?? CGPoint(x: screen.maxX - fitted.width - 24, y: screen.minY + 24)
        return CGRect(
            x: min(max(proposed.x, screen.minX), screen.maxX - fitted.width),
            y: min(max(proposed.y, screen.minY), screen.maxY - fitted.height),
            width: fitted.width,
            height: fitted.height
        )
    }

    private static func intersectionArea(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let overlap = first.intersection(second)
        return overlap.isNull ? 0 : overlap.width * overlap.height
    }

    private static func isFinite(_ rect: CGRect) -> Bool {
        [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy(\.isFinite)
    }
}
