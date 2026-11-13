import UIKit

enum GridDrawing {
    static func draw(in c: CGContext, size: CGSize, region: CountRegion, grid: NeubauerGrid) {
        func rect(_ r: CountRegion) -> CGRect {
            CGRect(x: r.x * size.width, y: r.y * size.height, width: r.width * size.width, height: r.height * size.height)
        }
        c.saveGState()
        let bounds = CGRect(origin: .zero, size: size), roi = rect(region)
        let shade = UIBezierPath(rect: bounds); shade.append(UIBezierPath(rect: roi)); shade.usesEvenOddFillRule = true
        UIColor.black.withAlphaComponent(0.35).setFill(); shade.fill()
        let short = min(size.width, size.height)
        let n = grid.mode.divisions
        if n > 1 {
            for index in 0..<(n * n) {
                let square = rect(grid.square(index, in: region))
                let selected = grid.selectedIndices.contains(index)
                c.setFillColor((selected ? UIColor.systemTeal.withAlphaComponent(0.06) : UIColor.black.withAlphaComponent(0.42)).cgColor)
                c.fill(square)
                c.setStrokeColor(UIColor.systemTeal.withAlphaComponent(selected ? 0.9 : 0.3).cgColor)
                c.setLineWidth(short * 0.0015); c.stroke(square)
                if selected {
                    let font = UIFont.monospacedDigitSystemFont(ofSize: short * 0.017, weight: .bold)
                    (grid.label(index) as NSString).draw(at: CGPoint(x: square.minX + 4, y: square.minY + 3),
                        withAttributes: [.font: font, .foregroundColor: UIColor.systemTeal])
                }
            }
        }
        c.setStrokeColor(UIColor(red: 0.38, green: 0.94, blue: 0.75, alpha: 1).cgColor)
        c.setLineWidth(short * 0.0025); c.setLineDash(phase: 0, lengths: [short * 0.012, short * 0.006])
        c.stroke(roi); c.restoreGState()
    }
}
