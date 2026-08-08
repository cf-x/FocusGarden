import SwiftUI

struct TreeArtwork: View {
    let kind: PlantKind
    var growth: Double = 1

    var body: some View {
        Canvas { context, size in
            let clampedGrowth = min(1, max(0, growth))
            let scale = 0.42 + 0.58 * clampedGrowth
            context.opacity = 0.58 + 0.42 * clampedGrowth
            context.translateBy(x: size.width * (1 - scale) / 2, y: size.height * (1 - scale))
            context.scaleBy(x: scale, y: scale)

            TreePainter.drawGround(in: &context, size: size, kind: kind)
            switch kind {
            case .birch:
                TreePainter.drawBirch(in: &context, size: size)
            case .maple:
                TreePainter.drawMaple(in: &context, size: size)
            case .cedar:
                TreePainter.drawCedar(in: &context, size: size)
            case .jacaranda:
                TreePainter.drawJacaranda(in: &context, size: size)
            case .ginkgo:
                TreePainter.drawGinkgo(in: &context, size: size)
            case .ancientBanyan:
                TreePainter.drawAncientBanyan(in: &context, size: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.name)，\(kind.durationLabel)")
    }
}

private enum TreePainter {
    static func point(_ x: CGFloat, _ y: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }

    static func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, in size: CGSize) -> CGRect {
        CGRect(x: size.width * x, y: size.height * y, width: size.width * width, height: size.height * height)
    }

    static func drawGround(in context: inout GraphicsContext, size: CGSize, kind: PlantKind) {
        let tint: Color = switch kind {
        case .birch: .green
        case .maple: .mint
        case .cedar: Color(red: 0.16, green: 0.35, blue: 0.25)
        case .jacaranda: .purple
        case .ginkgo: .yellow
        case .ancientBanyan: .cyan
        }
        context.fill(
            Path(ellipseIn: rect(0.19, 0.84, 0.62, 0.09, in: size)),
            with: .color(tint.opacity(0.16))
        )
    }

    static func stroke(
        _ path: Path,
        in context: inout GraphicsContext,
        color: Color,
        width: CGFloat
    ) {
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }

    static func ellipse(
        _ box: CGRect,
        in context: inout GraphicsContext,
        colors: [Color],
        angle: Bool = false
    ) {
        let start = angle ? CGPoint(x: box.minX, y: box.maxY) : CGPoint(x: box.midX, y: box.minY)
        let end = angle ? CGPoint(x: box.maxX, y: box.minY) : CGPoint(x: box.midX, y: box.maxY)
        context.fill(
            Path(ellipseIn: box),
            with: .linearGradient(Gradient(colors: colors), startPoint: start, endPoint: end)
        )
    }

    static func drawBirch(in context: inout GraphicsContext, size: CGSize) {
        let trunkWidth = max(4, size.width * 0.055)
        var left = Path()
        left.move(to: point(0.43, 0.84, in: size))
        left.addCurve(to: point(0.40, 0.34, in: size), control1: point(0.46, 0.67, in: size), control2: point(0.36, 0.49, in: size))
        stroke(left, in: &context, color: Color(red: 0.89, green: 0.91, blue: 0.81), width: trunkWidth)

        var right = Path()
        right.move(to: point(0.55, 0.84, in: size))
        right.addCurve(to: point(0.60, 0.40, in: size), control1: point(0.52, 0.68, in: size), control2: point(0.63, 0.53, in: size))
        stroke(right, in: &context, color: Color(red: 0.77, green: 0.83, blue: 0.72), width: trunkWidth * 0.78)

        for (x, y, w, h) in [(0.26, 0.23, 0.30, 0.27), (0.43, 0.17, 0.34, 0.29), (0.52, 0.33, 0.27, 0.24), (0.20, 0.39, 0.28, 0.23)] {
            ellipse(
                rect(x, y, w, h, in: size),
                in: &context,
                colors: [Color(red: 0.65, green: 0.92, blue: 0.52), Color(red: 0.24, green: 0.67, blue: 0.35)],
                angle: true
            )
        }

        for (x, y) in [(0.39, 0.55), (0.42, 0.65), (0.58, 0.58)] {
            var mark = Path()
            mark.move(to: point(x - 0.025, y, in: size))
            mark.addLine(to: point(x + 0.018, y + 0.01, in: size))
            stroke(mark, in: &context, color: Color.black.opacity(0.28), width: max(1, size.width * 0.012))
        }
    }

    static func drawMaple(in context: inout GraphicsContext, size: CGSize) {
        let trunkColor = Color(red: 0.36, green: 0.24, blue: 0.13)
        var trunk = Path()
        trunk.move(to: point(0.50, 0.84, in: size))
        trunk.addCurve(to: point(0.49, 0.42, in: size), control1: point(0.44, 0.68, in: size), control2: point(0.54, 0.55, in: size))
        trunk.move(to: point(0.49, 0.51, in: size))
        trunk.addCurve(to: point(0.30, 0.36, in: size), control1: point(0.42, 0.44, in: size), control2: point(0.38, 0.39, in: size))
        trunk.move(to: point(0.49, 0.48, in: size))
        trunk.addCurve(to: point(0.69, 0.31, in: size), control1: point(0.57, 0.41, in: size), control2: point(0.62, 0.34, in: size))
        stroke(trunk, in: &context, color: trunkColor, width: max(5, size.width * 0.07))

        for (x, y, w, h, light) in [
            (0.13, 0.25, 0.33, 0.28, false),
            (0.29, 0.13, 0.39, 0.34, true),
            (0.55, 0.22, 0.34, 0.30, false),
            (0.23, 0.37, 0.34, 0.26, true),
            (0.50, 0.37, 0.31, 0.25, true)
        ] {
            ellipse(
                rect(x, y, w, h, in: size),
                in: &context,
                colors: light
                    ? [Color(red: 0.35, green: 0.88, blue: 0.48), Color(red: 0.08, green: 0.50, blue: 0.29)]
                    : [Color(red: 0.22, green: 0.72, blue: 0.36), Color(red: 0.05, green: 0.38, blue: 0.24)],
                angle: true
            )
        }
    }

    static func drawCedar(in context: inout GraphicsContext, size: CGSize) {
        var trunk = Path()
        trunk.move(to: point(0.50, 0.85, in: size))
        trunk.addLine(to: point(0.50, 0.19, in: size))
        stroke(trunk, in: &context, color: Color(red: 0.27, green: 0.19, blue: 0.13), width: max(5, size.width * 0.055))

        let tiers: [(CGFloat, CGFloat, CGFloat, Color)] = [
            (0.18, 0.20, 0.64, Color(red: 0.12, green: 0.42, blue: 0.28)),
            (0.22, 0.33, 0.56, Color(red: 0.10, green: 0.36, blue: 0.25)),
            (0.27, 0.47, 0.46, Color(red: 0.08, green: 0.31, blue: 0.22)),
            (0.32, 0.60, 0.36, Color(red: 0.07, green: 0.27, blue: 0.20))
        ]
        for (x, y, width, color) in tiers {
            var tier = Path()
            tier.move(to: point(0.50, y - 0.17, in: size))
            tier.addLine(to: point(x, y + 0.18, in: size))
            tier.addQuadCurve(to: point(x + width, y + 0.18, in: size), control: point(0.50, y + 0.12, in: size))
            tier.closeSubpath()
            context.fill(tier, with: .linearGradient(
                Gradient(colors: [color.opacity(0.82), color]),
                startPoint: point(x, y, in: size),
                endPoint: point(x + width, y + 0.12, in: size)
            ))
        }

        for (x, y) in [(0.34, 0.34), (0.62, 0.46), (0.41, 0.58)] {
            context.fill(Path(ellipseIn: rect(x, y, 0.035, 0.035, in: size)), with: .color(Color.white.opacity(0.48)))
        }
    }

    static func drawJacaranda(in context: inout GraphicsContext, size: CGSize) {
        let trunkColor = Color(red: 0.31, green: 0.22, blue: 0.20)
        var branches = Path()
        branches.move(to: point(0.48, 0.84, in: size))
        branches.addCurve(to: point(0.48, 0.39, in: size), control1: point(0.42, 0.68, in: size), control2: point(0.53, 0.53, in: size))
        branches.move(to: point(0.48, 0.48, in: size))
        branches.addCurve(to: point(0.25, 0.31, in: size), control1: point(0.39, 0.40, in: size), control2: point(0.33, 0.34, in: size))
        branches.move(to: point(0.49, 0.46, in: size))
        branches.addCurve(to: point(0.73, 0.28, in: size), control1: point(0.59, 0.39, in: size), control2: point(0.65, 0.31, in: size))
        stroke(branches, in: &context, color: trunkColor, width: max(5, size.width * 0.065))

        for (x, y, w, h, light) in [
            (0.08, 0.19, 0.37, 0.28, false),
            (0.30, 0.10, 0.40, 0.31, true),
            (0.57, 0.18, 0.36, 0.28, false),
            (0.19, 0.34, 0.32, 0.24, true),
            (0.48, 0.33, 0.34, 0.25, true)
        ] {
            ellipse(
                rect(x, y, w, h, in: size),
                in: &context,
                colors: light
                    ? [Color(red: 0.66, green: 0.53, blue: 0.96), Color(red: 0.35, green: 0.28, blue: 0.70)]
                    : [Color(red: 0.49, green: 0.38, blue: 0.86), Color(red: 0.25, green: 0.20, blue: 0.58)],
                angle: true
            )
        }

        for (x, y) in [(0.24, 0.61), (0.69, 0.58), (0.36, 0.70), (0.77, 0.70)] {
            context.fill(Path(ellipseIn: rect(x, y, 0.028, 0.035, in: size)), with: .color(Color(red: 0.71, green: 0.56, blue: 0.98)))
        }
    }

    static func drawGinkgo(in context: inout GraphicsContext, size: CGSize) {
        var trunk = Path()
        trunk.move(to: point(0.49, 0.84, in: size))
        trunk.addCurve(to: point(0.50, 0.35, in: size), control1: point(0.43, 0.64, in: size), control2: point(0.56, 0.49, in: size))
        trunk.move(to: point(0.50, 0.48, in: size))
        trunk.addLine(to: point(0.29, 0.30, in: size))
        trunk.move(to: point(0.51, 0.45, in: size))
        trunk.addLine(to: point(0.70, 0.25, in: size))
        stroke(trunk, in: &context, color: Color(red: 0.38, green: 0.27, blue: 0.14), width: max(5, size.width * 0.06))

        for (x, y, w, h, color) in [
            (0.11, 0.17, 0.34, 0.31, Color(red: 0.97, green: 0.71, blue: 0.12)),
            (0.31, 0.08, 0.38, 0.33, Color(red: 1.00, green: 0.82, blue: 0.24)),
            (0.57, 0.14, 0.34, 0.31, Color(red: 0.93, green: 0.62, blue: 0.08)),
            (0.22, 0.34, 0.31, 0.25, Color(red: 0.95, green: 0.76, blue: 0.16)),
            (0.49, 0.33, 0.32, 0.25, Color(red: 1.00, green: 0.85, blue: 0.28))
        ] {
            var fan = Path()
            fan.move(to: point(x + w / 2, y + h, in: size))
            fan.addCurve(
                to: point(x, y + h * 0.34, in: size),
                control1: point(x + w * 0.28, y + h * 0.86, in: size),
                control2: point(x, y + h * 0.66, in: size)
            )
            fan.addQuadCurve(to: point(x + w, y + h * 0.34, in: size), control: point(x + w / 2, y - h * 0.13, in: size))
            fan.addCurve(
                to: point(x + w / 2, y + h, in: size),
                control1: point(x + w, y + h * 0.66, in: size),
                control2: point(x + w * 0.72, y + h * 0.86, in: size)
            )
            context.fill(fan, with: .color(color))
        }
    }

    static func drawAncientBanyan(in context: inout GraphicsContext, size: CGSize) {
        let trunkColor = Color(red: 0.28, green: 0.24, blue: 0.18)
        var trunk = Path()
        trunk.move(to: point(0.40, 0.85, in: size))
        trunk.addCurve(to: point(0.47, 0.40, in: size), control1: point(0.28, 0.68, in: size), control2: point(0.43, 0.54, in: size))
        trunk.move(to: point(0.59, 0.85, in: size))
        trunk.addCurve(to: point(0.49, 0.40, in: size), control1: point(0.67, 0.67, in: size), control2: point(0.55, 0.52, in: size))
        trunk.move(to: point(0.48, 0.47, in: size))
        trunk.addCurve(to: point(0.16, 0.30, in: size), control1: point(0.36, 0.38, in: size), control2: point(0.27, 0.33, in: size))
        trunk.move(to: point(0.50, 0.46, in: size))
        trunk.addCurve(to: point(0.84, 0.28, in: size), control1: point(0.64, 0.36, in: size), control2: point(0.74, 0.31, in: size))
        stroke(trunk, in: &context, color: trunkColor, width: max(7, size.width * 0.085))

        for (x, y, w, h, light) in [
            (0.01, 0.18, 0.35, 0.27, false),
            (0.19, 0.08, 0.39, 0.31, true),
            (0.43, 0.07, 0.39, 0.31, false),
            (0.68, 0.17, 0.31, 0.27, true),
            (0.12, 0.33, 0.36, 0.24, true),
            (0.38, 0.31, 0.37, 0.25, false),
            (0.64, 0.32, 0.27, 0.23, false)
        ] {
            ellipse(
                rect(x, y, w, h, in: size),
                in: &context,
                colors: light
                    ? [Color(red: 0.15, green: 0.67, blue: 0.51), Color(red: 0.04, green: 0.37, blue: 0.31)]
                    : [Color(red: 0.08, green: 0.50, blue: 0.42), Color(red: 0.02, green: 0.28, blue: 0.27)],
                angle: true
            )
        }

        for x in [0.22, 0.31, 0.69, 0.78] {
            var root = Path()
            root.move(to: point(x, 0.47, in: size))
            root.addLine(to: point(x + 0.015, 0.78, in: size))
            stroke(root, in: &context, color: trunkColor.opacity(0.72), width: max(1, size.width * 0.018))
        }

        for (x, y) in [(0.22, 0.20), (0.39, 0.15), (0.61, 0.18), (0.76, 0.27), (0.49, 0.28)] {
            context.fill(Path(ellipseIn: rect(x, y, 0.025, 0.025, in: size)), with: .color(Color(red: 0.61, green: 0.95, blue: 0.91).opacity(0.9)))
        }
    }
}
