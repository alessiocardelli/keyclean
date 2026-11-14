import SwiftUI

/// Tastiera in fil di ferro vista in prospettiva, con un pennellino che la spazza in diagonale.
/// Si ferma da sola dopo qualche ciclo (WCAG 2.2.2) e resta ferma con "Riduci movimento".
struct KeyboardIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        let still = finished || reduceMotion
        TimelineView(.animation(paused: still)) { timeline in
            // Da fermo si disegna l'istante zero: pennello a riposo accanto alla tastiera
            let time = still ? 0 : max(0, timeline.date.timeIntervalSince(start))
            Canvas { context, size in
                SweepScene.draw(in: &context, size: size, time: time)
            }
        }
        .task {
            start = Date()
            try? await Task.sleep(nanoseconds: UInt64(SweepScene.cycle * Double(SweepScene.cycles) * 1_000_000_000))
            finished = true
        }
        .accessibilityHidden(true)
    }
}

/// Geometria e disegno. Le misure della tastiera sono in "unità tasto" su un piano, poi proiettate in prospettiva.
private enum SweepScene {
    static let cycle = 4.0
    static let cycles = 3

    // Tempi dentro il ciclo: il pennello arriva, spazza, torna a riposo
    private static let sweepStart = 0.9
    private static let sweepEnd = 3.3

    // Piano della tastiera: 14,5 unità di larghezza, 5 file
    private static let boardWidth = 14.5
    private static let boardDepth = 5.0
    private static let rows: [[Double]] = [
        Array(repeating: 1.0, count: 13) + [1.5],
        [1.5] + Array(repeating: 1.0, count: 12) + [1.0],
        [1.75] + Array(repeating: 1.0, count: 11) + [1.75],
        [2.25] + Array(repeating: 1.0, count: 10) + [2.25],
        [1.0, 1.0, 1.0, 1.25, 5.0, 1.25, 1.0, 1.0, 1.0, 1.0],
    ]

    // Camera: tastiera ruotata di poco e vista dall'alto
    private static let yaw = -0.24
    private static let tilt = 0.68
    private static let cameraDistance = 26.0

    // Percorso del pennello sul piano: dal fondo a sinistra al davanti a destra, poi a riposo fuori dalla tastiera
    private static let from = Vec(x: 0.9, z: 0.5)
    private static let to = Vec(x: 13.6, z: 4.5)
    private static let rest = Vec(x: 15.7, z: 5.3)
    private static let reach = 1.7
    /// A riposo il pennello sta appena sollevato, accanto alla tastiera
    private static let restLift = 0.35

    private static let wire = Palette.sageShade

    struct Vec {
        var x: Double
        var z: Double
    }

    struct Key {
        let rect: CGRect
        /// Istante del ciclo in cui il pennello la raggiunge; nil se resta fuori dalla passata
        let hitTime: Double?
        let strength: Double
    }

    struct Speck {
        let origin: Vec
        let birth: Double
        let life: Double
        let drift: Double
        let rise: Double
        let radius: Double
    }

    private static let keys: [Key] = {
        var result: [Key] = []
        for (row, widths) in rows.enumerated() {
            var x = 0.0
            for width in widths {
                let rect = CGRect(x: x + 0.07, y: Double(row) + 0.07, width: width - 0.14, height: 0.86)
                let (along, across) = locate(Vec(x: rect.midX, z: rect.midY))
                let inside = across < reach && along > -0.05 && along < 1.05
                result.append(Key(rect: rect,
                                  hitTime: inside ? sweepTime(at: along) : nil,
                                  strength: inside ? 1 - pow(across / reach, 2) : 0))
                x += width
            }
        }
        return result
    }()

    private static let specks: [Speck] = (0..<30).map { index in
        let along = 0.04 + 0.86 * (Double(index) + noise(index, 1)) / 30
        var origin = brushPoint(along)
        let side = (noise(index, 2) - 0.5) * 1.3
        origin.x += normal.x * side
        origin.z += normal.z * side
        return Speck(origin: origin,
                     birth: sweepTime(at: along) + 0.05,
                     life: 0.75 + 0.4 * noise(index, 3),
                     drift: (noise(index, 4) - 0.5) * 30,
                     rise: 26 + 24 * noise(index, 5),
                     radius: 1.5 + 2.0 * noise(index, 6))
    }

    // MARK: Disegno

    static func draw(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let t = time.truncatingRemainder(dividingBy: cycle)
        let scale = size.width / 520
        // Luci e polvere si spengono prima che il ciclo ricominci
        let fade = 1 - smooth((t - 3.35) / 0.6)

        // Corpo della tastiera: una lastra sottile, con il bordo inferiore appena sotto
        let body = CGRect(x: -0.45, y: -0.45, width: boardWidth + 0.9, height: boardDepth + 0.9)
        let top = quad(body, radius: 0.55, in: size)
        let under = top.offsetBy(dx: 0, dy: 7 * scale)
        context.fill(under, with: .color(Palette.sageTop.opacity(0.22)))
        context.stroke(under, with: .color(wire.opacity(0.28)), lineWidth: scale)
        context.fill(top, with: .color(.white))
        context.stroke(top, with: .color(wire.opacity(0.6)), lineWidth: 1.3 * scale)

        for key in keys {
            let path = quad(key.rect, radius: 0.16, in: size)
            var glow = 0.0
            if let hitTime = key.hitTime, t >= hitTime {
                let age = t - hitTime
                glow = key.strength * min(1, age / 0.12) * exp(-age / 0.55) * fade
            }
            if glow > 0.01 {
                context.fill(path, with: .color(Palette.sageTop.opacity(0.95 * glow)))
            }
            context.stroke(path, with: .color(wire.opacity(0.42 + 0.5 * glow)), lineWidth: scale)
        }

        // Pennello: posizione sul piano e quanto è sollevato
        let pose = brushPose(at: t)
        let ground = project(pose.point, in: size)

        let shadowWidth = (24 - 9 * pose.lift) * scale
        let shadow = CGRect(x: ground.x - shadowWidth / 2, y: ground.y - 3 * scale, width: shadowWidth, height: 6 * scale)
        context.fill(Path(ellipseIn: shadow), with: .color(wire.opacity(0.16 * (1 - 0.6 * pose.lift))))

        for speck in specks where t > speck.birth && t < speck.birth + speck.life {
            let progress = (t - speck.birth) / speck.life
            let base = project(speck.origin, in: size)
            let lifted = 1 - pow(1 - progress, 2)
            let center = CGPoint(x: base.x + speck.drift * progress * scale, y: base.y - speck.rise * lifted * scale)
            let radius = speck.radius * (0.7 + 0.6 * progress) * scale
            let alpha = min(1, progress * 6) * (1 - progress * progress) * fade
            let dot = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: dot), with: .color(Palette.sageMid.opacity(alpha)))
        }

        let tip = CGPoint(x: ground.x, y: ground.y - pose.lift * 24 * scale)
        drawBrush(in: context, tip: tip, angle: 0.6 + pose.sway, scale: scale)
    }

    private static func drawBrush(in context: GraphicsContext, tip: CGPoint, angle: Double, scale: CGFloat) {
        var context = context
        context.translateBy(x: tip.x, y: tip.y)
        context.rotate(by: .radians(angle))
        context.scaleBy(x: scale, y: scale)

        // La punta è nell'origine, il pennello sale verso l'alto
        var handle = Path()
        handle.move(to: CGPoint(x: -5.5, y: -34))
        handle.addLine(to: CGPoint(x: 5.5, y: -34))
        handle.addCurve(to: CGPoint(x: 3, y: -106), control1: CGPoint(x: 7, y: -62), control2: CGPoint(x: 3.5, y: -90))
        handle.addQuadCurve(to: CGPoint(x: -3, y: -106), control: CGPoint(x: 0, y: -113))
        handle.addCurve(to: CGPoint(x: -5.5, y: -34), control1: CGPoint(x: -3.5, y: -90), control2: CGPoint(x: -7, y: -62))
        handle.closeSubpath()
        context.fill(handle, with: .color(.white))
        context.stroke(handle, with: .color(wire), lineWidth: 1.4)

        var bristles = Path()
        bristles.move(to: CGPoint(x: -7, y: -24))
        bristles.addLine(to: CGPoint(x: 7, y: -24))
        bristles.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 7, y: -6))
        bristles.addQuadCurve(to: CGPoint(x: -7, y: -24), control: CGPoint(x: -7, y: -6))
        bristles.closeSubpath()
        context.fill(bristles, with: .color(Palette.sageMid))
        context.stroke(bristles, with: .color(wire), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))

        let ferrule = Path(roundedRect: CGRect(x: -7.5, y: -35, width: 15, height: 11), cornerRadius: 2)
        context.fill(ferrule, with: .color(Palette.sageTop))
        context.stroke(ferrule, with: .color(wire), lineWidth: 1.4)
    }

    // MARK: Movimento

    private static func brushPose(at t: Double) -> (point: Vec, lift: Double, sway: Double) {
        if t < sweepStart {
            // Arrivo in volo dal punto di riposo, con un arco
            let p = t / sweepStart
            let e = smooth(p)
            return (mix(rest, from, e), restLift * (1 - e) + 0.8 * sin(.pi * p), 0)
        }
        if t < sweepEnd {
            let along = smooth((t - sweepStart) / (sweepEnd - sweepStart))
            return (brushPoint(along), 0, 0.12 * cos(along * 6 * .pi) * sin(.pi * along))
        }
        let p = (t - sweepEnd) / (cycle - sweepEnd)
        let e = smooth(p)
        return (mix(to, rest, e), restLift * e + 0.4 * sin(.pi * p), 0)
    }

    /// Punto del pennello lungo la passata: la diagonale più una leggera oscillazione ai lati.
    private static func brushPoint(_ along: Double) -> Vec {
        let wiggle = 0.45 * sin(along * 6 * .pi)
        let base = mix(from, to, along)
        return Vec(x: base.x + normal.x * wiggle, z: base.z + normal.z * wiggle)
    }

    private static let normal: Vec = {
        let dx = to.x - from.x, dz = to.z - from.z
        let length = (dx * dx + dz * dz).squareRoot()
        return Vec(x: -dz / length, z: dx / length)
    }()

    /// Posizione di un punto rispetto alla passata: avanzamento (0...1) e distanza laterale.
    private static func locate(_ point: Vec) -> (along: Double, across: Double) {
        let dx = to.x - from.x, dz = to.z - from.z
        let px = point.x - from.x, pz = point.z - from.z
        return ((px * dx + pz * dz) / (dx * dx + dz * dz), abs(px * normal.x + pz * normal.z))
    }

    /// Istante del ciclo in cui la passata arriva a un certo avanzamento (inverso della curva, per bisezione).
    private static func sweepTime(at along: Double) -> Double {
        let target = min(max(along, 0), 1)
        var low = 0.0, high = 1.0
        for _ in 0..<24 {
            let middle = (low + high) / 2
            if smooth(middle) < target { low = middle } else { high = middle }
        }
        return sweepStart + (low + high) / 2 * (sweepEnd - sweepStart)
    }

    private static func smooth(_ value: Double) -> Double {
        let x = min(max(value, 0), 1)
        return x * x * x * (x * (x * 6 - 15) + 10)
    }

    private static func mix(_ a: Vec, _ b: Vec, _ amount: Double) -> Vec {
        Vec(x: a.x + (b.x - a.x) * amount, z: a.z + (b.z - a.z) * amount)
    }

    private static func noise(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return value - value.rounded(.down)
    }

    // MARK: Prospettiva

    private static func project(_ point: Vec, in size: CGSize) -> CGPoint {
        let unit = size.width / 19.5
        let x = point.x - boardWidth / 2
        let z = boardDepth / 2 - point.z
        let turnedX = x * cos(yaw) - z * sin(yaw)
        let turnedZ = x * sin(yaw) + z * cos(yaw)
        let perspective = cameraDistance / (cameraDistance + turnedZ * cos(tilt))
        return CGPoint(x: size.width * 0.46 + turnedX * perspective * unit,
                       y: size.height * 0.62 - turnedZ * sin(tilt) * perspective * unit)
    }

    /// Rettangolo del piano con gli angoli arrotondati, proiettato.
    private static func quad(_ rect: CGRect, radius: Double, in size: CGSize) -> Path {
        let corners = [Vec(x: rect.minX, z: rect.minY), Vec(x: rect.maxX, z: rect.minY),
                       Vec(x: rect.maxX, z: rect.maxY), Vec(x: rect.minX, z: rect.maxY)]
        var path = Path()
        for index in 0..<4 {
            let corner = corners[index]
            let before = toward(corner, corners[(index + 3) % 4], radius)
            let after = toward(corner, corners[(index + 1) % 4], radius)
            if index == 0 {
                path.move(to: project(before, in: size))
            } else {
                path.addLine(to: project(before, in: size))
            }
            path.addQuadCurve(to: project(after, in: size), control: project(corner, in: size))
        }
        path.closeSubpath()
        return path
    }

    private static func toward(_ start: Vec, _ end: Vec, _ distance: Double) -> Vec {
        let dx = end.x - start.x, dz = end.z - start.z
        let length = (dx * dx + dz * dz).squareRoot()
        return Vec(x: start.x + dx / length * distance, z: start.z + dz / length * distance)
    }
}
