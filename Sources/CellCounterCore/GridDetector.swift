import Foundation

public struct GridDetection: Sendable {
    public var central: GridQuad?
    public var overview: GridQuad?
    public var corner: GridQuad?
    public var lineSupport: Double
    public var summary: String {
        if overview != nil { return "已定位完整九宫格及中央密集网格" }
        if central != nil { return "已定位中央 5×5 中格；未定位到完整九宫格外框" }
        if corner != nil { return "已定位 4×4 分格的大格候选；请核对角位与实物" }
        return "未可靠定位计数板边框，请手动框选或重新拍摄"
    }
    public func alignment(for mode: CountingMode) -> GridQuad? {
        switch mode { case .overview: overview; case .redBloodCells: central; case .singleLarge: corner; case .custom: nil }
    }
}

/// Repeated rulings are located independently of cells. The illuminated circle
/// is a visibility mask, never a physical counting border.
public enum GridDetector {
    private struct Lattice {
        var start: Double; var end: Double; var score: Double; var support: Double
    }
    public static func detect(_ image: GrayImage) -> GridDetection {
        var result = GridDetection(central: nil, overview: nil, corner: nil, lineSupport: 0)
        let w = image.width, h = image.height
        guard w >= 80, h >= 80, w <= 2048, h <= 2048, image.pixels.count == w*h else { return result }
        let g = ImageMath.gaussian(image.pixels.map(Float.init), width: w, height: h, sigma: 0.7)
        for polarity in [Float(1), Float(-1)] {
            var vx = [Float](repeating: 0, count: w*h), hy = vx
            var xp = [Double](repeating: 0, count: w), yp = [Double](repeating: 0, count: h)
            var xn = [Int](repeating: 0, count: w), yn = [Int](repeating: 0, count: h)
            let delta = max(3, min(w,h)/288)
            for y in delta..<(h-delta) { for x in delta..<(w-delta) {
                let p = y*w+x
                guard g[p] > 65 else { continue }
                vx[p] = max(0, polarity * (g[p] - (g[p-delta]+g[p+delta])/2))
                hy[p] = max(0, polarity * (g[p] - (g[p-delta*w]+g[p+delta*w])/2))
                xp[x] += Double(vx[p]); yp[y] += Double(hy[p]); xn[x] += 1; yn[y] += 1
            } }
            for x in 0..<w { xp[x] = xn[x] > h*2/5 ? xp[x]/Double(xn[x]) : 0 }
            for y in 0..<h { yp[y] = yn[y] > w*2/5 ? yp[y]/Double(yn[y]) : 0 }
            xp = smooth(xp); yp = smooth(yp)
            if let a = fit(xp, intervals: 20), let b = fit(yp, intervals: 20), compatible(a,b),
               let quad = refine(a,b,vx:vx,hy:hy,w:w,h:h), quad.isValid {
                let strength = min(a.support,b.support)
                if result.central == nil || strength > result.lineSupport {
                    result.central = quad; result.lineSupport = strength
                    let outer = GridQuad(topLeft: quad.project(x:-1,y:-1), topRight: quad.project(x:2,y:-1),
                        bottomRight: quad.project(x:2,y:2), bottomLeft: quad.project(x:-1,y:2))
                    // Full 3 mm reference requires observed outer sides and visible corners.
                    result.overview = outer.isValid && visible(outer,g:g,w:w,h:h) && edgesSupported(outer,vx:vx,hy:hy,w:w,h:h) ? outer : nil
                }
            }
            if result.central == nil, let a = fit(xp, intervals: 4), let b = fit(yp, intervals: 4),
               compatible(a,b), let quad = refine(a,b,vx:vx,hy:hy,w:w,h:h), quad.isValid,
               visible(quad,g:g,w:w,h:h), edgesSupported(quad,vx:vx,hy:hy,w:w,h:h) {
                result.corner = quad; result.lineSupport = min(a.support,b.support)
            }
        }
        if result.central != nil { result.corner = nil }
        return result
    }
    private static func smooth(_ p: [Double]) -> [Double] {
        var out = p
        for i in 2..<(p.count-2) { out[i] = (p[i-2]+4*p[i-1]+6*p[i]+4*p[i+1]+p[i+2])/16 }
        return out
    }
    private static func fit(_ p: [Double], intervals: Int) -> Lattice? {
        let noise = ImageMath.median(p.filter { $0 > 0 })
        var peaks: [Int] = []
        for i in 8..<(p.count-8) where p[i] >= p[i-1] && p[i] > p[i+1] {
            let left = p[(i-8)..<i].min() ?? p[i], right = p[(i+1)...(i+8)].min() ?? p[i]
            if p[i] - max(left,right) > 0.65 && p[i] > max(1.2,noise+0.5) {
                if let last = peaks.last, i-last < 8 { if p[i] > p[last] { peaks[peaks.count-1] = i } }
                else { peaks.append(i) }
            }
        }
        guard peaks.count >= intervals+1 else { return nil }
        var best: Lattice?
        let minSpan = Double(p.count)*(intervals == 20 ? 0.18 : 0.42)
        for a in peaks { for b in peaks where b > a && Double(b-a) >= minSpan && Double(b-a) <= Double(p.count)*0.94 {
            let step = Double(b-a)/Double(intervals)
            guard step >= (intervals == 20 ? 8 : 15) else { continue }
            var values: [Double] = []
            for k in 0...intervals {
                let index = Int((Double(a)+Double(k)*step).rounded()), r = min(4,max(2,Int(step*0.12)))
                values.append(p[max(0,index-r)...min(p.count-1,index+r)].max() ?? 0)
            }
            let hits = values.filter { $0 > max(1.8,noise+0.8) }.count
            guard hits >= (intervals == 20 ? 19 : 5), ImageMath.median(values) > noise+1,
                  p[a] > noise+1, p[b] > noise+1 else { continue }
            let mean = values.map { min($0,10) }.reduce(0,+)/Double(values.count)
            let score = mean + ImageMath.median(values) + Double(hits)*0.3 + 0.6*(p[a]+p[b])
            if best == nil || score > best!.score {
                best = Lattice(start:Double(a),end:Double(b),score:score,support:Double(hits)/Double(intervals+1))
            }
        } }
        return best
    }
    private static func compatible(_ x: Lattice, _ y: Lattice) -> Bool {
        let ratio = (x.end-x.start)/(y.end-y.start)
        return ratio > 0.72 && ratio < 1.38
    }
    private static func side(_ response: [Float], position: Double, low: Double, high: Double,
                             vertical: Bool, w: Int, h: Int) -> (Double,Double)? {
        var points: [(Double,Double)] = []
        let size = vertical ? w : h, length = vertical ? h : w
        for bin in 0..<16 {
            let from = max(1,Int(low+(high-low)*Double(bin)/16)), to = min(length-2,Int(low+(high-low)*Double(bin+1)/16))
            let lo = max(1,Int(position)-10), hi = min(size-2,Int(position)+10)
            guard to > from, hi > lo else { continue }
            var profile = [Double](repeating:0,count:hi-lo+1)
            for q in lo...hi {
                for t in from...to { profile[q-lo] += Double(response[vertical ? t*w+q : q*w+t]) }
                profile[q-lo] /= Double(to-from+1)
            }
            guard let strongest = profile.indices.max(by:{profile[$0]<profile[$1]}), profile[strongest] > 1.5 else { continue }
            var peak = strongest
            let ridges = (1..<(profile.count-1)).filter {
                profile[$0] > profile[$0-1] && profile[$0] >= profile[$0+1] && profile[$0] > profile[strongest]*0.4
            }
            if ridges.count >= 3 {
                for i in 0..<(ridges.count-2) {
                    let a = ridges[i], b = ridges[i+1], c = ridges[i+2]
                    if b-a >= 2 && c-b >= 2 && b-a <= 6 && c-b <= 6 && [a,b,c].contains(strongest) {
                        peak = b; break // three-line ruling: the middle line is the reference
                    }
                }
            }
            var weight = 0.0, coordinate = 0.0
            for i in max(0,peak-3)...min(profile.count-1,peak+3) {
                let v = max(0,profile[i]-profile[peak]*0.5)
                weight += v; coordinate += v*Double(i+lo)
            }
            if weight > 0 { points.append((Double(from+to)/2,coordinate/weight)) }
        }
        guard points.count >= 10 else { return nil }
        func regression(_ p: [(Double,Double)]) -> (Double,Double) {
            let mx = p.map{$0.0}.reduce(0,+)/Double(p.count), my = p.map{$0.1}.reduce(0,+)/Double(p.count)
            let num = p.map{($0.0-mx)*($0.1-my)}.reduce(0,+), den = p.map{pow($0.0-mx,2)}.reduce(0,+)
            let slope = den > 0 ? num/den : 0
            return (my-slope*mx,slope)
        }
        var line = regression(points)
        points = points.filter{abs($0.1-line.0-line.1*$0.0)<4}
        guard points.count >= 9 else { return nil }
        line = regression(points)
        return abs(line.1) < 0.08 ? line : nil
    }
    private static func refine(_ x: Lattice, _ y: Lattice, vx:[Float],hy:[Float],w:Int,h:Int) -> GridQuad? {
        guard let l = side(vx,position:x.start,low:y.start,high:y.end,vertical:true,w:w,h:h),
              let r = side(vx,position:x.end,low:y.start,high:y.end,vertical:true,w:w,h:h),
              let t = side(hy,position:y.start,low:x.start,high:x.end,vertical:false,w:w,h:h),
              let b = side(hy,position:y.end,low:x.start,high:x.end,vertical:false,w:w,h:h) else { return nil }
        func intersection(_ v:(Double,Double),_ hline:(Double,Double))->GridPoint {
            let xx = (v.0+v.1*hline.0)/(1-v.1*hline.1), yy = hline.0+hline.1*xx
            return GridPoint(x:xx/Double(w),y:yy/Double(h))
        }
        return GridQuad(topLeft:intersection(l,t),topRight:intersection(r,t),bottomRight:intersection(r,b),bottomLeft:intersection(l,b))
    }
    private static func visible(_ q:GridQuad,g:[Float],w:Int,h:Int)->Bool {
        q.corners.allSatisfy { p in
            let x = min(w-1,max(0,Int(p.x*Double(w)))), y = min(h-1,max(0,Int(p.y*Double(h))))
            return g[y*w+x] > 70
        }
    }
    private static func edgesSupported(_ q:GridQuad,vx:[Float],hy:[Float],w:Int,h:Int)->Bool {
        for edge in 0..<4 {
            let a = q.corners[edge], b = q.corners[(edge+1)%4], vertical = edge%2 == 1
            var hits = 0
            for k in 1..<100 {
                let f = Double(k)/100, x = Int((a.x+(b.x-a.x)*f)*Double(w)), y = Int((a.y+(b.y-a.y)*f)*Double(h))
                var value:Float = 0
                for delta in -3...3 {
                    let xx = min(w-1,max(0,x+(vertical ? delta:0))), yy = min(h-1,max(0,y+(vertical ? 0:delta)))
                    value = max(value,(vertical ? vx:hy)[yy*w+xx])
                }
                if value > 3 { hits += 1 }
            }
            if hits < 65 { return false }
        }
        return true
    }
}
