import Foundation

public struct CellDetectionReport: Sendable {
    public var markers: [CellMarker]
    public var estimatedDiameterPixels: Double
    public var componentsExamined: Int
    public var rejectedShape: Int
    public var rejectedContrast: Int
    public var excludedByRegion: Int
}

/// Fine-scale contrast preserves phase-contrast rings while rejecting broad
/// illumination valleys. Connected recovered supports remain one counting object.
public enum CellDetector {
    public static func detect(_ image: GrayImage, region: CountRegion,
                              settings: DetectionSettings, grid: NeubauerGrid? = nil,
                              alignment: GridQuad? = nil) -> [CellMarker] {
        analyze(image, region: region, settings: settings, grid: grid, alignment: alignment).markers
    }
    public static func analyze(_ image: GrayImage, region: CountRegion,
                               settings: DetectionSettings, grid: NeubauerGrid? = nil,
                               alignment: GridQuad? = nil) -> CellDetectionReport {
        var report = CellDetectionReport(markers: [], estimatedDiameterPixels: 0,
            componentsExamined: 0, rejectedShape: 0, rejectedContrast: 0, excludedByRegion: 0)
        let w = image.width, h = image.height
        guard w > 4, h > 4, w <= 2048, h <= 2048, image.pixels.count == w * h,
              region.isValid, settings.isValid, grid?.isValid != false else { return report }
        let short = Double(min(w, h))
        let pixels = image.pixels.map(Float.init)
        let fine = ImageMath.gaussian(pixels, width: w, height: h, sigma: 0.7)
        let background = ImageMath.gaussian(pixels, width: w, height: h, sigma: max(2.5, short / 400))
        guard !Task.isCancelled else { return report }
        let signed = zip(fine,background).map(-)
        let noise = ImageMath.localNoise(signed,width:w,height:h)
        let sensitivity = Float(min(1,max(0,settings.sensitivity)))
        let step = max(8,min(w,h)/85)
        var response = [Float](repeating: 0, count: pixels.count)
        var threshold = response, seedThreshold = response
        var mask = [UInt8](repeating: 0, count: pixels.count)
        for y in 0..<h {
            guard !Task.isCancelled else { return report }
            for x in 0..<w {
                let p = y*w+x, r = signed[p]
                let v = ImageMath.median5(signed[max(0,y-2*step)*w+x],signed[max(0,y-step)*w+x],r,
                    signed[min(h-1,y+step)*w+x],signed[min(h-1,y+2*step)*w+x])
                let hline = ImageMath.median5(signed[y*w+max(0,x-2*step)],signed[y*w+max(0,x-step)],r,
                    signed[y*w+min(w-1,x+step)],signed[y*w+min(w-1,x+2*step)])
                // Subtract only the matching polarity. Unbounded subtraction followed
                // by abs() would invent inverse-polarity cells next to a real cell.
                let bright = max(0,r-max(0,v)-max(0,hline))
                let dark = max(0,-r-max(0,-v)-max(0,-hline))
                response[p] = settings.automaticPolarity ? max(bright,dark) : (settings.brightCells ? bright : dark)
                let floor = max(0.8,1.4*noise[p])
                threshold[p] = floor + max(0,18-floor)*pow(1-sensitivity,2)
                seedThreshold[p] = threshold[p]+max(0.7,0.75*noise[p])
                if response[p] > threshold[p] && background[p] > 55 { mask[p] = 1 }
            }
        }
        // A one-pixel cross closing repairs broken rims and touching clumps.
        // We do not erase grid strips, which would cut cells crossing a ruling.
        mask = ImageMath.closingCross(mask, width: w, height: h)
        struct Component {
            var minX: Int; var minY: Int; var maxX: Int; var maxY: Int
            var count: Int; var sumX: Int; var sumY: Int; var strong: Int; var original: Int
            var diameter: Double { Double(max(maxX-minX+1, maxY-minY+1)) }
            var aspect: Double {
                let w = Double(maxX-minX+1), h = Double(maxY-minY+1)
                return max(w/h,h/w)
            }
            var fill: Double { Double(count) / Double((maxX-minX+1)*(maxY-minY+1)) }
        }
        var components: [Component] = [], queue: [Int] = []
        for seed in 0..<(w*h) where mask[seed] == 1 {
            guard !Task.isCancelled else { return report }
            report.componentsExamined += 1
            queue.removeAll(keepingCapacity: true); queue.append(seed); mask[seed] = 0
            var head = 0
            var c = Component(minX: w, minY: h, maxX: 0, maxY: 0, count: 0, sumX: 0, sumY: 0, strong: 0, original: 0)
            while head < queue.count {
                if head % 4096 == 0 && Task.isCancelled { return report }
                let p = queue[head]; head += 1
                let x = p % w, y = p / w
                c.count += 1; c.sumX += x; c.sumY += y
                c.minX = min(c.minX,x); c.maxX = max(c.maxX,x)
                c.minY = min(c.minY,y); c.maxY = max(c.maxY,y)
                if response[p] > threshold[p] { c.original += 1 }
                if response[p] > seedThreshold[p] { c.strong += 1 }
                for ny in max(0,y-1)...min(h-1,y+1) { for nx in max(0,x-1)...min(w-1,x+1) {
                    let next = ny*w+nx
                    if mask[next] == 1 { mask[next] = 0; queue.append(next) }
                } }
            }
            guard c.diameter >= 3, c.diameter <= short * 0.25,
                  c.count >= 6, c.aspect < 5, c.fill >= 0.16 else { report.rejectedShape += 1; continue }
            guard c.strong >= 3, Double(c.strong) / Double(max(1,c.original)) >= 0.25 else {
                report.rejectedContrast += 1; continue
            }
            components.append(c)
        }
        let isolatedSizes = components.filter { $0.aspect < 2 && $0.diameter <= short * 0.15 && $0.count >= 10 }.map(\.diameter)
        let estimated = ImageMath.median(isolatedSizes.isEmpty ? components.filter { $0.aspect < 2 }.map(\.diameter) : isolatedSizes)
        report.estimatedDiameterPixels = estimated
        // The upper sensitivity range also recovers small incomplete rims;
        // manual diameter limits remain explicit user choices.
        let recovery = max(0,(Double(sensitivity)-0.7)/0.3)
        let sizeFraction = 0.5-0.2*recovery
        let minimum = settings.automaticSize ? max(4, estimated > 0 ? estimated * sizeFraction : 4) : max(3, settings.minimumDiameter * short)
        let maximum = settings.automaticSize ? max(20, estimated * 5) : settings.maximumDiameter * short * 3
        let layout = grid ?? NeubauerGrid(mode: .custom)
        for c in components {
            let shortSide = min(c.maxX-c.minX+1,c.maxY-c.minY+1)
            guard c.diameter >= minimum, c.diameter <= maximum,
                  (shortSide >= 4 || (sensitivity > 0.8 && shortSide >= 3 && c.aspect <= 1.8)),
                  Double(c.count) >= max(sensitivity > 0.8 ? 8 : 12, minimum * minimum * 0.18) else { report.rejectedShape += 1; continue }
            let extent = CountRegion(x: Double(c.minX)/Double(w), y: Double(c.minY)/Double(h),
                width: Double(c.maxX-c.minX+1)/Double(w), height: Double(c.maxY-c.minY+1)/Double(h))
            let marker = CellMarker(x: (Double(c.sumX)/Double(c.count)+0.5)/Double(w),
                y: (Double(c.sumY)/Double(c.count)+0.5)/Double(h), radius: (c.diameter/2+0.8)/short, extent: extent)
            guard layout.assignedIndex(for: marker, in: region, alignment: alignment) != nil else {
                report.excludedByRegion += 1; continue
            }
            report.markers.append(marker)
        }
        report.markers.sort { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
        return report
    }
}
