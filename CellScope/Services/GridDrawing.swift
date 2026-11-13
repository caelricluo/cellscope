import UIKit

enum GridDrawing {
    static func draw(in c: CGContext, size: CGSize, region: CountRegion, grid: NeubauerGrid, alignment: GridQuad? = nil) {
        let quad = alignment ?? GridQuad(region: region)
        func point(_ p: GridPoint) -> CGPoint { CGPoint(x: p.x * size.width, y: p.y * size.height) }
        func polygon(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> UIBezierPath {
            let p = UIBezierPath()
            p.move(to: point(quad.project(x: x, y: y)))
            p.addLine(to: point(quad.project(x: x + width, y: y)))
            p.addLine(to: point(quad.project(x: x + width, y: y + height)))
            p.addLine(to: point(quad.project(x: x, y: y + height))); p.close()
            return p
        }
        c.saveGState()
        let outer = polygon(0, 0, 1, 1)
        let shade = UIBezierPath(rect: CGRect(origin: .zero, size: size)); shade.append(outer); shade.usesEvenOddFillRule = true
        UIColor.black.withAlphaComponent(0.35).setFill(); shade.fill()
        let short = min(size.width, size.height), n = grid.mode.divisions
        if n > 1 {
            for index in 0..<(n*n) {
                let x = Double(index%n)/Double(n), y = Double(index/n)/Double(n)
                let path = polygon(x,y,1/Double(n),1/Double(n)), selected = grid.selectedIndices.contains(index)
                (selected ? UIColor.systemTeal.withAlphaComponent(0.04) : UIColor.black.withAlphaComponent(0.42)).setFill(); path.fill()
                UIColor.systemTeal.withAlphaComponent(selected ? 0.9 : 0.3).setStroke()
                path.lineWidth = short*0.0015; path.stroke()
                if selected {
                    let p = point(quad.project(x:x,y:y))
                    (grid.label(index) as NSString).draw(at: CGPoint(x:p.x+4,y:p.y+3), withAttributes:[
                        .font:UIFont.monospacedDigitSystemFont(ofSize:short*0.014,weight:.bold),.foregroundColor:UIColor.systemTeal])
                }
            }
        }
        UIColor(red:0.38,green:0.94,blue:0.75,alpha:1).setStroke()
        outer.lineWidth = short*0.0025; outer.setLineDash([short*0.012,short*0.006],count:2,phase:0); outer.stroke()
        c.restoreGState()
    }
}
