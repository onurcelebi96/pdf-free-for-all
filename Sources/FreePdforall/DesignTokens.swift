import AppKit
import SwiftUI

enum DeskColors {
    static let canvas = Color(lightHex: 0xF5F6F8, darkHex: 0x1C1D21)
    static let surface = Color(lightHex: 0xFFFFFF, darkHex: 0x25262C)
    static let navigator = Color(lightHex: 0xFAFAFC, darkHex: 0x222329)
    static let documentSheet = Color(lightHex: 0xFFFFFF, darkHex: 0xFFFFFF)
    static let ink = Color(lightHex: 0x24262D, darkHex: 0xF4F5F8)
    static let prominentCard = Color(lightHex: 0x24262D, darkHex: 0x323640)
    static let signatureInk = Color(lightHex: 0x24262D, darkHex: 0x24262D)
    static let secondary = Color(lightHex: 0x656B78, darkHex: 0xAEB3BF)
    static let action = Color(lightHex: 0x2459D3, darkHex: 0x8BACFF)
    static let actionHover = Color(lightHex: 0x1945AD, darkHex: 0xB4CAFF)
    static let selection = Color(lightHex: 0xEBF1FF, darkHex: 0x293957)
    static let divider = Color(lightHex: 0xE2E5EB, darkHex: 0x3B3E48)
    static let documentStage = Color(lightHex: 0xF7F7F7, darkHex: 0x14151A)
    static let success = Color(lightHex: 0x28745F, darkHex: 0x8CD0B4)
    static let warning = Color(lightHex: 0x825514, darkHex: 0xF2C877)
    static let destructive = Color(lightHex: 0xA13D36, darkHex: 0xFF938A)
}

private extension Color {
    init(lightHex: UInt32, darkHex: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let value = isDark ? darkHex : lightHex
            return NSColor(
                srgbRed: CGFloat((value >> 16) & 0xff) / 255,
                green: CGFloat((value >> 8) & 0xff) / 255,
                blue: CGFloat(value & 0xff) / 255,
                alpha: 1
            )
        })
    }
}
