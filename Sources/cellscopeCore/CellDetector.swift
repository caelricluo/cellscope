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
              region.isValid, settings.sensitivity.isFinite,
              settings.minimumDiameter.isFinite, settings.maximumDiameter.isFinite,
              (settings.automaticSize || (settings.minimumDiameter > 0 && settings.maximumDiameter >= settings.minimumDiameter &&
              settings.maximumDiameter <= 1)), grid?.isValid != false else { return report }
        let short = Double(min(w, h))
        let pixels = image.pixels.map(Float.init)
        let fine = ImageMath.gaussian(pixels, width: w, height: h, sigma: 0.7)
        let background = ImageMath.gaussian(pixels, width: w, height: h, sigma: max(2.5, short / 400))
        guard !Task.isCancelled else { return report }
        let threshold = Float(8 + (1 - min(1, max(0, settings.sensitivity))) * 10)
        var response = [Float](repeating: 0, count: pixels.count)
        var mask = [UInt8](repeating: 0, count: pixels.count)
        for p in pixels.indices {
            response[p] = settings.brightCells ? fine[p] - background[p] : background[p] - fine[p]
            if response[p] > threshold && background[p] > 55 { mask[p] = 1 }
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
                if response[p] > threshold { c.original += 1 }
                if response[p] > threshold + 3 { c.strong += 1 }
                for ny in max(0,y-1)...min(h-1,y+1) { for nx in max(0,x-1)...min(w-1,x+1) {
                    let next = ny*w+nx
                    if mask[next] == 1 { mask[next] = 0; queue.append(next) }
                } }
            }
            guard c.diameter >= 3, c.diameter <= short * 0.2,
                  c.count >= 6, c.aspect < 5, c.fill >= 0.16 else { report.rejectedShape += 1; continue }
            guard c.strong >= 3, Double(c.strong) / Double(max(1,c.original)) >= 0.25 else {
                report.rejectedContrast += 1; continue
            }
            components.append(c)
        }
        let isolatedSizes = components.filter { $0.aspect < 2 && $0.diameter <= short * 0.06 && $0.count >= 10 }.map(\.diameter)
        let estimated = ImageMath.median(isolatedSizes.isEmpty ? components.filter { $0.aspect < 2 }.map(\.diameter) : isolatedSizes)
        report.estimatedDiameterPixels = estimated
        let minimum = settings.automaticSize ? max(4, estimated > 0 ? estimated * 0.45 : 4) : max(3, settings.minimumDiameter * short)
        let maximum = settings.automaticSize ? max(20, estimated * 5) : settings.maximumDiameter * short * 3
        let layout = grid ?? NeubauerGrid(mode: .custom)
        for c in components {
            guard c.diameter >= minimum, c.diameter <= maximum,
                  min(c.maxX-c.minX+1,c.maxY-c.minY+1) >= 4,
                  Double(c.count) >= max(12, minimum * minimum * 0.18) else { report.rejectedShape += 1; continue }
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
