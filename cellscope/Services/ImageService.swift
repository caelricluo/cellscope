import UIKit

enum ImageService {
    static func normalized(_ image: UIImage, maxEdge: CGFloat = 1600) -> UIImage {
        let ratio = min(1, maxEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, image.size.width * ratio), height: max(1, image.size.height * ratio))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func grayscale(_ image: UIImage) -> GrayImage? {
        let reduced = normalized(image, maxEdge: 1600)
        guard let cg = reduced.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h)
        let success = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            // CGContext buffer rows follow the CGImage raster's top-to-bottom order.
            context.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return success ? GrayImage(width: w, height: h, pixels: pixels) : nil
    }

    #if DEBUG
    static func faintCellTestImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size:CGSize(width:400,height:400),format:format).image { renderer in
            let c = renderer.cgContext
            c.setFillColor(gray:0.7,alpha:1);c.fill(CGRect(x:0,y:0,width:400,height:400))
            for (x,y,bright) in [(80,85,true),(180,100,false),(300,90,true),(110,260,false),(300,280,true)] {
                c.setFillColor(gray:bright ? 0.725 : 0.675,alpha:1)
                c.fillEllipse(in:CGRect(x:x-4,y:y-4,width:8,height:8))
            }
        }
    }
    #endif

    /// Deterministic synthetic fixture, visibly labeled in every result.
    static func demo(mode: CountingMode = .singleLarge) -> UIImage {
        if mode == .overview || mode == .redBloodCells { return gridDemo(mode: mode) }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1000), format: format).image { renderer in
            let c = renderer.cgContext
            UIColor(white: 0.87, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 1000, height: 1000))
            c.setStrokeColor(UIColor(white: 0.6, alpha: 1).cgColor); c.setLineWidth(2)
            for i in 0...4 {
                let p = CGFloat(100 + i * 200)
                c.move(to: CGPoint(x: p, y: 100)); c.addLine(to: CGPoint(x: p, y: 900))
                c.move(to: CGPoint(x: 100, y: p)); c.addLine(to: CGPoint(x: 900, y: p))
            }
            c.strokePath()
            for row in 0..<7 {
                for col in 0..<7 {
                    let positions = [145, 245, 345, 445, 545, 645, 845]
                    let x = CGFloat(positions[col] + (row * 7 + col * 11) % 11)
                    let y = CGFloat(positions[row] + (col * 13 + row * 3) % 11)
                    let radius = CGFloat(12 + (row + col) % 5)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    c.setFillColor(UIColor(white: 0.46, alpha: 1).cgColor); c.fillEllipse(in: rect)
                    c.setFillColor(UIColor(white: 0.73, alpha: 1).cgColor); c.fillEllipse(in: rect.insetBy(dx: 4, dy: 4))
                }
            }
        }
    }

    static func gridDemo(mode: CountingMode) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1000), format: format).image { renderer in
            let c = renderer.cgContext
            c.setFillColor(UIColor(white: 0.87, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: 1000, height: 1000))
            let n = mode.divisions, side = 800.0 / Double(n)
            for row in 0..<n { for col in 0..<n {
                let origin = CGPoint(x: 100 + Double(col) * side, y: 100 + Double(row) * side)
                let sub = mode == .redBloodCells || (row != 1 || col != 1) ? 4 : 20
                c.setStrokeColor(UIColor(white: 0.81, alpha: 1).cgColor); c.setLineWidth(1)
                for k in 1..<sub {
                    let offset = Double(k) * side / Double(sub)
                    c.move(to: CGPoint(x: origin.x + offset, y: origin.y)); c.addLine(to: CGPoint(x: origin.x + offset, y: origin.y + side))
                    c.move(to: CGPoint(x: origin.x, y: origin.y + offset)); c.addLine(to: CGPoint(x: origin.x + side, y: origin.y + offset))
                }
                c.strokePath()
                let points: [Double] = mode == .redBloodCells ? [0.32, 0.68] : [0.12, 0.37, 0.87]
                for py in points { for px in points {
                    let radius = mode == .redBloodCells ? 7.0 : 6.0
                    let rect = CGRect(x: origin.x + px * side - radius, y: origin.y + py * side - radius, width: radius * 2, height: radius * 2)
                    c.setFillColor(UIColor(white: 0.45, alpha: 1).cgColor); c.fillEllipse(in: rect)
                    c.setFillColor(UIColor(white: 0.72, alpha: 1).cgColor); c.fillEllipse(in: rect.insetBy(dx: 3, dy: 3))
                } }
            } }
            c.setStrokeColor(UIColor(white: 0.6, alpha: 1).cgColor); c.setLineWidth(2)
            for k in 0...n {
                let p = 100 + Double(k) * side
                c.move(to: CGPoint(x: p, y: 100)); c.addLine(to: CGPoint(x: p, y: 900))
                c.move(to: CGPoint(x: 100, y: p)); c.addLine(to: CGPoint(x: 900, y: p))
            }
            c.strokePath()
        }
    }

    static func annotated(_ image: UIImage, markers: [CellMarker], region: CountRegion, grid: NeubauerGrid = NeubauerGrid(mode: .custom), alignment: GridQuad? = nil) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { renderer in
            image.draw(at: .zero)
            let c = renderer.cgContext
            GridDrawing.draw(in: c, size: image.size, region: region, grid: grid, alignment: alignment)
            c.setLineWidth(1.5)
            for (index, marker) in markers.enumerated() {
                let p = CGPoint(x: marker.x * image.size.width, y: marker.y * image.size.height)
                let r = marker.radius * min(image.size.width, image.size.height)
                c.setStrokeColor((marker.isManual ? UIColor.systemOrange : UIColor.systemTeal).cgColor)
                c.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                ("\(index + 1)" as NSString).draw(at: CGPoint(x: p.x + r, y: p.y - r), withAttributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold), .foregroundColor: UIColor.systemTeal
                ])
            }
        }
    }
}
