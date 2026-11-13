import Foundation

public struct GridPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// A projective reference, in upright normalized image coordinates.
public struct GridQuad: Codable, Equatable, Sendable {
    public var topLeft: GridPoint
    public var topRight: GridPoint
    public var bottomRight: GridPoint
    public var bottomLeft: GridPoint
    public init(topLeft: GridPoint, topRight: GridPoint, bottomRight: GridPoint, bottomLeft: GridPoint) {
        self.topLeft = topLeft; self.topRight = topRight
        self.bottomRight = bottomRight; self.bottomLeft = bottomLeft
    }
    public init(region: CountRegion) {
        self.init(topLeft: GridPoint(x: region.x, y: region.y),
            topRight: GridPoint(x: region.x + region.width, y: region.y),
            bottomRight: GridPoint(x: region.x + region.width, y: region.y + region.height),
            bottomLeft: GridPoint(x: region.x, y: region.y + region.height))
    }
    public var corners: [GridPoint] { [topLeft, topRight, bottomRight, bottomLeft] }
    public var bounds: CountRegion {
        let xs = corners.map(\.x), ys = corners.map(\.y)
        let x = max(0, xs.min() ?? 0), y = max(0, ys.min() ?? 0)
        return CountRegion(x: x, y: y, width: min(1, xs.max() ?? 0) - x, height: min(1, ys.max() ?? 0) - y)
    }
    public var isValid: Bool {
        guard corners.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.x >= 0 && $0.x <= 1 && $0.y >= 0 && $0.y <= 1 }) else { return false }
        let p = corners
        for i in 0..<4 {
            let a = p[i], b = p[(i+1)%4], c = p[(i+2)%4]
            if (b.x-a.x)*(c.y-b.y) - (b.y-a.y)*(c.x-b.x) <= 1e-8 { return false }
        }
        return bounds.isValid && matrix != nil
    }
    private var matrix: [Double]? {
        let a = topLeft, b = topRight, c = bottomRight, d = bottomLeft
        let dx1 = b.x-c.x, dx2 = d.x-c.x, dx3 = a.x-b.x+c.x-d.x
        let dy1 = b.y-c.y, dy2 = d.y-c.y, dy3 = a.y-b.y+c.y-d.y
        var g = 0.0, h = 0.0
        if abs(dx3) + abs(dy3) > 1e-12 {
            let den = dx1*dy2-dx2*dy1
            guard abs(den) > 1e-12 else { return nil }
            g = (dx3*dy2-dx2*dy3)/den; h = (dx1*dy3-dx3*dy1)/den
        }
        return [b.x-a.x+g*b.x, d.x-a.x+h*d.x, a.x,
                b.y-a.y+g*b.y, d.y-a.y+h*d.y, a.y, g, h, 1]
    }
    public func project(x: Double, y: Double) -> GridPoint {
        guard let m = matrix else { return GridPoint(x: .nan, y: .nan) }
        let z = m[6]*x+m[7]*y+1
        return GridPoint(x: (m[0]*x+m[1]*y+m[2])/z, y: (m[3]*x+m[4]*y+m[5])/z)
    }
    public func unproject(_ point: GridPoint) -> GridPoint? {
        guard let m = matrix else { return nil }
        let a = m[0], b = m[1], c = m[2], d = m[3], e = m[4], f = m[5], g = m[6], h = m[7]
        let inv = [e-f*h, c*h-b, b*f-c*e, f*g-d, a-c*g, c*d-a*f, d*h-e*g, b*g-a*h, a*e-b*d]
        let z = inv[6]*point.x+inv[7]*point.y+inv[8]
        guard abs(z) > 1e-12 else { return nil }
        let p = GridPoint(x: (inv[0]*point.x+inv[1]*point.y+inv[2])/z, y: (inv[3]*point.x+inv[4]*point.y+inv[5])/z)
        return p.x.isFinite && p.y.isFinite ? p : nil
    }
    public func markerInUnitSquare(_ marker: CellMarker) -> CellMarker? {
        guard isValid, let p = unproject(GridPoint(x: marker.x, y: marker.y)) else { return nil }
        var result = marker; result.x = p.x; result.y = p.y
        if let r = marker.extent {
            let points = GridQuad(region: r).corners.compactMap(unproject)
            guard points.count == 4 else { return nil }
            let xs = points.map(\.x), ys = points.map(\.y)
            let x = xs.min()!, y = ys.min()!
            result.extent = CountRegion(x: x, y: y, width: xs.max()!-x, height: ys.max()!-y)
        }
        return result
    }
}

public enum GridHandle: Int, CaseIterable, Identifiable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, move
    public var id: Int { rawValue }
    public var title: String {
        switch self {
        case .topLeft: "左上角"; case .top: "上边"; case .topRight: "右上角"; case .right: "右边"
        case .bottomRight: "右下角"; case .bottom: "下边"; case .bottomLeft: "左下角"; case .left: "左边"; case .move: "整体"
        }
    }
    var indices: [Int] {
        switch self {
        case .topLeft: [0]; case .top: [0,1]; case .topRight: [1]; case .right: [1,2]
        case .bottomRight: [2]; case .bottom: [2,3]; case .bottomLeft: [3]; case .left: [3,0]; case .move: [0,1,2,3]
        }
    }
    public func point(in quad: GridQuad) -> GridPoint {
        let p = indices.map { quad.corners[$0] }
        return GridPoint(x:p.map(\.x).reduce(0,+)/Double(p.count), y:p.map(\.y).reduce(0,+)/Double(p.count))
    }
}

extension GridQuad {
    /// Apply a normalized image displacement to a corner, edge, or the whole
    /// frame, clamping the selected points together at the image boundary.
    public func adjusting(_ handle: GridHandle, dx: Double, dy: Double) -> GridQuad {
        guard isValid, dx.isFinite, dy.isFinite else { return self }
        var p = corners
        let selected = handle.indices.map { p[$0] }
        let x = min(1-selected.map(\.x).max()!,max(-selected.map(\.x).min()!,dx))
        let y = min(1-selected.map(\.y).max()!,max(-selected.map(\.y).min()!,dy))
        for i in handle.indices { p[i].x += x; p[i].y += y }
        let result = GridQuad(topLeft:p[0],topRight:p[1],bottomRight:p[2],bottomLeft:p[3])
        guard result.isValid, result.bounds.width >= 0.04, result.bounds.height >= 0.04 else { return self }
        for i in 0..<4 where hypot(p[i].x-p[(i+1)%4].x,p[i].y-p[(i+1)%4].y)<0.025 { return self }
        return result
    }
}
