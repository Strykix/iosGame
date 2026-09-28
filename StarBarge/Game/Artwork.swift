import SpriteKit
import UIKit

/// All visuals are drawn at runtime with CoreGraphics + SF Symbols. No image assets required.
struct SkinPalette {
    let bodyLight: UIColor
    let bodyDark: UIColor
    let tiles: UIColor
    let accent: UIColor
    let flame: UIColor
    let flameCore: UIColor
    let tilesCoverage: CGFloat
    let soot: Bool

    static func palette(for skin: Skin) -> SkinPalette {
        switch skin {
        case .prototype:
            return SkinPalette(
                bodyLight: UIColor(hex: 0xD3D8DE), bodyDark: UIColor(hex: 0x868D96),
                tiles: UIColor(hex: 0x2B2E33), accent: UIColor(hex: 0x5A6069),
                flame: UIColor(hex: 0xFF8A2A), flameCore: UIColor(hex: 0xFFF1B8),
                tilesCoverage: 0.3, soot: false
            )
        case .flight11:
            return SkinPalette(
                bodyLight: UIColor(hex: 0xC9CED4), bodyDark: UIColor(hex: 0x7C838C),
                tiles: UIColor(hex: 0x16181B), accent: UIColor(hex: 0xFF6A1F),
                flame: UIColor(hex: 0xFF7A1A), flameCore: UIColor(hex: 0xFFE7A0),
                tilesCoverage: 0.5, soot: false
            )
        case .banana:
            return SkinPalette(
                bodyLight: UIColor(hex: 0xFFE45C), bodyDark: UIColor(hex: 0xE0B521),
                tiles: UIColor(hex: 0x6B4A1E), accent: UIColor(hex: 0x3F7A2A),
                flame: UIColor(hex: 0xFFD23F), flameCore: UIColor(hex: 0xFFFFFF),
                tilesCoverage: 0.08, soot: false
            )
        case .recovered:
            return SkinPalette(
                bodyLight: UIColor(hex: 0xB9B2A8), bodyDark: UIColor(hex: 0x5E5850),
                tiles: UIColor(hex: 0x2A2521), accent: UIColor(hex: 0x3FD17A),
                flame: UIColor(hex: 0x4FA8FF), flameCore: UIColor(hex: 0xD9F0FF),
                tilesCoverage: 0.3, soot: true
            )
        case .chrome:
            return SkinPalette(
                bodyLight: UIColor(hex: 0xFFFFFF), bodyDark: UIColor(hex: 0x8E9AAB),
                tiles: UIColor(hex: 0x3A4250), accent: UIColor(hex: 0xFF4FD8),
                flame: UIColor(hex: 0xFF5FD2), flameCore: UIColor(hex: 0xFFE0F7),
                tilesCoverage: 0.2, soot: false
            )
        }
    }
}

enum Artwork {
    // MARK: - Rocket

    static func shipImage(skin: Skin, size: CGSize) -> UIImage {
        let palette = SkinPalette.palette(for: skin)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let w = size.width
            let h = size.height
            let bodyW = w * 0.62
            let left = (w - bodyW) / 2
            let noseH = h * 0.3

            let body = UIBezierPath()
            body.move(to: CGPoint(x: left, y: h))
            body.addLine(to: CGPoint(x: left, y: noseH))
            body.addCurve(
                to: CGPoint(x: w / 2, y: 0),
                controlPoint1: CGPoint(x: left, y: noseH * 0.35),
                controlPoint2: CGPoint(x: w / 2 - bodyW * 0.18, y: 0)
            )
            body.addCurve(
                to: CGPoint(x: left + bodyW, y: noseH),
                controlPoint1: CGPoint(x: w / 2 + bodyW * 0.18, y: 0),
                controlPoint2: CGPoint(x: left + bodyW, y: noseH * 0.35)
            )
            body.addLine(to: CGPoint(x: left + bodyW, y: h))
            body.close()

            if skin == .banana {
                let curve = CGAffineTransform(a: 1, b: 0, c: -0.06, d: 1, tx: h * 0.03, ty: 0)
                body.apply(curve)
            }

            cg.saveGState()
            body.addClip()
            drawMetal(cg, rect: CGRect(x: 0, y: 0, width: w, height: h), palette: palette, chrome: skin == .chrome)
            // Heat shield tiles on one side.
            palette.tiles.setFill()
            UIRectFill(CGRect(x: left, y: 0, width: bodyW * palette.tilesCoverage, height: h))
            if palette.soot { drawSoot(cg, size: size) }
            // Banana tip.
            if skin == .banana {
                palette.tiles.setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: w, height: h * 0.07))
            }
            cg.restoreGState()

            // Flaps.
            palette.accent.setFill()
            let fwd = UIBezierPath()
            fwd.move(to: CGPoint(x: left, y: noseH * 0.95))
            fwd.addLine(to: CGPoint(x: 0, y: noseH * 1.25))
            fwd.addLine(to: CGPoint(x: left, y: noseH * 1.45))
            fwd.close()
            fwd.fill()
            let fwdR = UIBezierPath()
            fwdR.move(to: CGPoint(x: left + bodyW, y: noseH * 0.95))
            fwdR.addLine(to: CGPoint(x: w, y: noseH * 1.25))
            fwdR.addLine(to: CGPoint(x: left + bodyW, y: noseH * 1.45))
            fwdR.close()
            fwdR.fill()

            let aft = UIBezierPath()
            aft.move(to: CGPoint(x: left, y: h * 0.72))
            aft.addLine(to: CGPoint(x: 0, y: h * 0.9))
            aft.addLine(to: CGPoint(x: 0, y: h))
            aft.addLine(to: CGPoint(x: left, y: h))
            aft.close()
            aft.fill()
            let aftR = UIBezierPath()
            aftR.move(to: CGPoint(x: left + bodyW, y: h * 0.72))
            aftR.addLine(to: CGPoint(x: w, y: h * 0.9))
            aftR.addLine(to: CGPoint(x: w, y: h))
            aftR.addLine(to: CGPoint(x: left + bodyW, y: h))
            aftR.close()
            aftR.fill()
        }
    }

    static func boosterImage(skin: Skin, size: CGSize) -> UIImage {
        let palette = SkinPalette.palette(for: skin)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let w = size.width
            let h = size.height
            let bodyW = w * 0.62
            let left = (w - bodyW) / 2
            let bodyRect = CGRect(x: left, y: 0, width: bodyW, height: h * 0.94)

            cg.saveGState()
            UIBezierPath(rect: bodyRect).addClip()
            drawMetal(cg, rect: bodyRect, palette: palette, chrome: skin == .chrome)
            if palette.soot { drawSoot(cg, size: size) }
            // Hot-staging vent ring.
            palette.tiles.setFill()
            UIRectFill(CGRect(x: left, y: 0, width: bodyW, height: h * 0.06))
            UIColor.orange.withAlphaComponent(0.8).setFill()
            for i in 0..<4 {
                let x = left + bodyW * (0.1 + CGFloat(i) * 0.22)
                UIRectFill(CGRect(x: x, y: h * 0.015, width: bodyW * 0.1, height: h * 0.03))
            }
            cg.restoreGState()

            // Grid fins.
            palette.accent.setFill()
            UIRectFill(CGRect(x: 0, y: h * 0.1, width: left, height: h * 0.07))
            UIRectFill(CGRect(x: left + bodyW, y: h * 0.1, width: left, height: h * 0.07))

            // Engine bells.
            palette.bodyDark.setFill()
            let bellW = bodyW / 3.2
            for i in 0..<3 {
                let x = left + CGFloat(i) * (bodyW - bellW) / 2
                let bell = UIBezierPath()
                bell.move(to: CGPoint(x: x + bellW * 0.25, y: h * 0.94))
                bell.addLine(to: CGPoint(x: x + bellW * 0.75, y: h * 0.94))
                bell.addLine(to: CGPoint(x: x + bellW, y: h))
                bell.addLine(to: CGPoint(x: x, y: h))
                bell.close()
                bell.fill()
            }
        }
    }

    private static func drawMetal(_ cg: CGContext, rect: CGRect, palette: SkinPalette, chrome: Bool) {
        let colors: [CGColor]
        let locations: [CGFloat]
        if chrome {
            colors = [palette.bodyDark, palette.bodyLight, palette.bodyDark, palette.bodyLight, palette.bodyDark].map(\.cgColor)
            locations = [0, 0.3, 0.55, 0.75, 1]
        } else {
            colors = [palette.bodyDark, palette.bodyLight, palette.bodyLight, palette.bodyDark].map(\.cgColor)
            locations = [0, 0.4, 0.6, 1]
        }
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
            palette.bodyLight.setFill()
            UIRectFill(rect)
            return
        }
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.midY),
            end: CGPoint(x: rect.maxX, y: rect.midY),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        // Weld seams.
        UIColor.black.withAlphaComponent(0.12).setFill()
        var y = rect.minY + rect.height * 0.12
        while y < rect.maxY {
            UIRectFill(CGRect(x: rect.minX, y: y, width: rect.width, height: 1))
            y += max(6, rect.height * 0.12)
        }
    }

    private static func drawSoot(_ cg: CGContext, size: CGSize) {
        var rng = SeededRandom(seed: 42)
        for _ in 0..<14 {
            let r = CGFloat(rng.next(in: 3...9))
            let x = CGFloat(rng.nextDouble()) * size.width
            let y = CGFloat(rng.next(in: 0.3...1)) * size.height
            UIColor(white: 0.1, alpha: 0.45).setFill()
            cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
    }

    // MARK: - Obstacles

    static func debrisImage(size: CGSize, seed: Int) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            var rng = SeededRandom(seed: UInt64(seed))
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let path = UIBezierPath()
            let points = 7
            for i in 0..<points {
                let angle = Double(i) / Double(points) * 2 * .pi
                let radius = rng.next(in: 0.62...0.98) * Double(min(size.width, size.height)) / 2
                let point = CGPoint(x: center.x + CGFloat(cos(angle) * radius), y: center.y + CGFloat(sin(angle) * radius))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.close()
            UIColor(hex: 0x7A7F87).setFill()
            path.fill()
            UIColor(hex: 0x3B3F45).setStroke()
            path.lineWidth = 2
            path.stroke()
            UIColor(hex: 0xFFB020).setFill()
            cg.fill(CGRect(x: center.x - size.width * 0.25, y: center.y - 2, width: size.width * 0.5, height: 4))
            UIColor(hex: 0x2B2E33).setFill()
            for _ in 0..<4 {
                let x = center.x + CGFloat(rng.next(in: -0.25...0.25)) * size.width
                let y = center.y + CGFloat(rng.next(in: -0.25...0.25)) * size.height
                cg.fillEllipse(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
            }
        }
    }

    static func droneImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let w = size.width
            let h = size.height
            UIColor(hex: 0x30343A).setFill()
            cg.fill(CGRect(x: w * 0.05, y: h * 0.12, width: w * 0.9, height: h * 0.08))
            UIColor(white: 0.85, alpha: 0.7).setFill()
            cg.fillEllipse(in: CGRect(x: 0, y: h * 0.02, width: w * 0.32, height: h * 0.12))
            cg.fillEllipse(in: CGRect(x: w * 0.68, y: h * 0.02, width: w * 0.32, height: h * 0.12))

            let body = UIBezierPath(roundedRect: CGRect(x: w * 0.2, y: h * 0.22, width: w * 0.6, height: h * 0.6), cornerRadius: h * 0.14)
            UIColor(hex: 0xF4F4F6).setFill()
            body.fill()
            UIColor(hex: 0x30343A).setStroke()
            body.lineWidth = 2
            body.stroke()

            let config = UIImage.SymbolConfiguration(pointSize: h * 0.34, weight: .bold)
            if let camera = UIImage(systemName: "video.fill", withConfiguration: config)?.withTintColor(UIColor(hex: 0x30343A), renderingMode: .alwaysOriginal) {
                let rect = CGRect(x: w / 2 - camera.size.width / 2, y: h * 0.52 - camera.size.height / 2, width: camera.size.width, height: camera.size.height)
                camera.draw(in: rect)
            }
            UIColor(hex: 0xFF2D2D).setFill()
            cg.fillEllipse(in: CGRect(x: w * 0.68, y: h * 0.28, width: h * 0.12, height: h * 0.12))
        }
    }

    /// Rasterized: SpriteKit ignores the tint of SF Symbol (template) images.
    static func windSymbolImage(pointSize: CGFloat) -> UIImage {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .heavy)
        guard let symbol = UIImage(systemName: "wind", withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) else { return UIImage() }
        return UIGraphicsImageRenderer(size: symbol.size).image { _ in
            symbol.draw(at: .zero)
        }
    }

    static func towerImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let w = size.width
            let h = size.height
            UIColor(hex: 0x4A4F57).setStroke()
            cg.setLineWidth(2)
            cg.stroke(CGRect(x: w * 0.1, y: h * 0.05, width: w * 0.45, height: h * 0.95))
            var y = h * 0.05
            var flip = false
            while y < h {
                cg.move(to: CGPoint(x: w * 0.1, y: y))
                cg.addLine(to: CGPoint(x: w * 0.55, y: y + w * 0.45 * (flip ? 1 : 1)))
                y += w * 0.45
                flip.toggle()
            }
            cg.strokePath()
            // "Chopsticks" catch arms.
            UIColor(hex: 0x2F3339).setFill()
            cg.fill(CGRect(x: w * 0.55, y: h * 0.18, width: w * 0.45, height: 4))
            cg.fill(CGRect(x: w * 0.55, y: h * 0.26, width: w * 0.45, height: 4))
        }
    }

    // MARK: - Particles

    static let softDot: SKTexture = {
        let size = CGSize(width: 32, height: 32)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawRadialGradient(
                    gradient, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                    endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: []
                )
            }
        }
        return SKTexture(image: image)
    }()

    static let confettiPiece: SKTexture = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 14)).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 8, height: 14))
        }
        return SKTexture(image: image)
    }()

    static let staticNoise: [SKTexture] = (0..<3).map { index in
        var rng = SeededRandom(seed: UInt64(index + 7))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 180, height: 320)).image { context in
            for y in stride(from: 0, to: 320, by: 3) {
                for x in stride(from: 0, to: 180, by: 3) {
                    UIColor(white: CGFloat(rng.nextDouble()), alpha: 1).setFill()
                    context.cgContext.fill(CGRect(x: x, y: y, width: 3, height: 3))
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    static func lerp(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var (ar, ag, ab, aa): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (br, bg, bb, ba): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let t = min(max(t, 0), 1)
        return UIColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t, blue: ab + (bb - ab) * t, alpha: aa + (ba - aa) * t)
    }
}
