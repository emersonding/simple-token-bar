import AppKit
import TokenBarCore

@MainActor
final class StatusIconRenderer {
    static func renderIcon(usedPercent: Double?) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let color: NSColor
            if let pct = usedPercent {
                switch pct {
                case ..<50:  color = NSColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1)  // #34C759 green
                case ..<80:  color = NSColor(red: 1.000, green: 0.584, blue: 0.000, alpha: 1)  // #FF9500 yellow
                default:     color = NSColor(red: 1.000, green: 0.231, blue: 0.188, alpha: 1)  // #FF3B30 red
                }
            } else {
                color = NSColor.systemGray
            }
            color.setFill()
            let inset = rect.insetBy(dx: 2, dy: 2)
            NSBezierPath(ovalIn: inset).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
