import CoreImage
import UIKit

/// Focus peaking: evidenzia i contorni nitidi con un colore.
enum Peaking {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func color(named name: String) -> CIColor {
        switch name {
        case "giallo": return CIColor(red: 1, green: 1, blue: 0)
        case "azzurro": return CIColor(red: 0, green: 1, blue: 1)
        case "bianco": return CIColor(red: 1, green: 1, blue: 1)
        default: return CIColor(red: 1, green: 0, blue: 0)
        }
    }

    /// threshold: 0.05 (molto sensibile) ... 0.6 (poco sensibile)
    static func apply(jpeg: Data, threshold: Double, color: CIColor) -> UIImage? {
        guard let input = CIImage(data: jpeg) else { return nil }
        let edges = input.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 3.0])
        let k: CGFloat = 8
        let t = CGFloat(threshold)
        // colore fisso, trasparenza proporzionale all'intensita' del contorno
        let mask = edges
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0.2126 * k, y: 0.7152 * k, z: 0.0722 * k, w: 0),
                "inputBiasVector": CIVector(x: color.red, y: color.green, z: color.blue, w: -t * k),
            ])
            .applyingFilter("CIColorClamp")
        let out = mask.composited(over: input)
        guard let cg = context.createCGImage(out, from: input.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
