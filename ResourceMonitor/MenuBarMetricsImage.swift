import AppKit

enum MenuBarMetricsImage {
    // Locked layout — icons stay put; spacing stays tight.
    private static let iconSize: CGFloat = 16
    private static let fontSize: CGFloat = 13
    private static let height: CGFloat = 18
    private static let iconTextGap: CGFloat = 2
    private static let groupGap: CGFloat = 6

    static func make(cpuUsage: Double, memoryUsage: Double) -> NSImage {
        let digitFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: digitFont,
            .foregroundColor: NSColor.black // template image; menu bar recolors it
        ]

        // Exact width of widest percent keeps layout stable without leftover padding.
        let percentSlotWidth = ceil(("100%" as NSString).size(withAttributes: textAttributes).width)

        let cpuIcon = symbolImage(named: "cpu")
        let memIcon = symbolImage(named: "memorychip", fallback: "internaldrive")

        let cpuText = percentString(cpuUsage) as NSString
        let memText = percentString(memoryUsage) as NSString

        let width =
            iconSize + iconTextGap + percentSlotWidth
            + groupGap
            + iconSize + iconTextGap + percentSlotWidth

        let size = NSSize(width: ceil(width), height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high

        var x: CGFloat = 0
        let iconY = (height - iconSize) / 2

        drawIcon(cpuIcon, at: NSPoint(x: x, y: iconY))
        x += iconSize + iconTextGap
        drawPercent(cpuText, in: NSRect(x: x, y: 0, width: percentSlotWidth, height: height), attributes: textAttributes)
        x += percentSlotWidth + groupGap

        drawIcon(memIcon, at: NSPoint(x: x, y: iconY))
        x += iconSize + iconTextGap
        drawPercent(memText, in: NSRect(x: x, y: 0, width: percentSlotWidth, height: height), attributes: textAttributes)

        image.isTemplate = true
        return image
    }

    private static func percentString(_ ratio: Double) -> String {
        let value = Int((min(1, max(0, ratio)) * 100).rounded())
        return "\(value)%"
    }

    private static func drawPercent(
        _ text: NSString,
        in rect: NSRect,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let textSize = text.size(withAttributes: attributes)
        let point = NSPoint(
            x: rect.minX,
            y: (rect.height - textSize.height) / 2
        )
        text.draw(at: point, withAttributes: attributes)
    }

    private static func drawIcon(_ icon: NSImage, at origin: NSPoint) {
        let rect = NSRect(origin: origin, size: NSSize(width: iconSize, height: iconSize))
        icon.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
        )
    }

    private static func symbolImage(named name: String, fallback: String? = nil) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            let copy = image.copy() as! NSImage
            copy.isTemplate = true
            return copy
        }
        if let fallback,
           let image = NSImage(systemSymbolName: fallback, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            let copy = image.copy() as! NSImage
            copy.isTemplate = true
            return copy
        }
        return NSImage(size: NSSize(width: iconSize, height: iconSize))
    }
}
