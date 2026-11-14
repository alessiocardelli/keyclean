import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Icona macOS dal disegno sorgente (Resources/design/app-icon-source.webp): ritaglia lo squircle dentro
// il suo bordo bianco, lo rimaschera con una superellisse pulita (fuori trasparente, niente aloni) e lo posa
// sulla griglia Apple: corpo 824 centrato su 1024, margine per l'ombra. Stesso metodo di BatteryGuard.
// uso: make-icon <sorgente> <uscita.png>
let args = CommandLine.arguments
guard args.count == 3,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    FileHandle.standardError.write("uso: make-icon <sorgente> <uscita.png>\n".data(using: .utf8)!)
    exit(1)
}

// Squircle nel sorgente 1254x1254 (misurato: x 62-1191, y 60-1213 col bordo in basso) e rientro che scarta il filo chiaro
let squircleBox = CGRect(x: 62, y: 60, width: 1130, height: 1125)
let inset: CGFloat = 28
let crop = squircleBox.insetBy(dx: inset, dy: inset)

let canvas: CGFloat = 1024
let body: CGFloat = 824
let bodyRect = CGRect(x: (canvas - body) / 2, y: (canvas - body) / 2, width: body, height: body)

/// Superellisse |x|^n + |y|^n = 1, la forma delle icone di sistema.
func superellipse(in rect: CGRect, exponent n: Double = 5, steps: Int = 720) -> CGPath {
    let path = CGMutablePath()
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = rect.midX + rect.width / 2 * CGFloat(copysign(pow(abs(c), 2 / n), c))
        let y = rect.midY + rect.height / 2 * CGFloat(copysign(pow(abs(s), 2 / n), s))
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.interpolationQuality = .high
let shape = superellipse(in: bodyRect)

// Ombra della griglia Apple
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.35))
ctx.addPath(shape)
ctx.setFillColor(CGColor(gray: 0.5, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

guard let cropped = image.cropping(to: crop) else { exit(1) }
ctx.saveGState()
ctx.addPath(shape)
ctx.clip()
ctx.draw(cropped, in: bodyRect)
ctx.restoreGState()

guard let result = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, result, nil)
CGImageDestinationFinalize(dest)
