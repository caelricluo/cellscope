import Foundation

/// Local contrast + connected components. Candidates require human review.
/// This is deliberately independent of UIKit so numerical behavior is testable.
public enum CellDetector {
    public static func detect(_ image: GrayImage, region: CountRegion,
                              settings: DetectionSettings, grid: NeubauerGrid? = nil) -> [CellMarker] {
        let w = image.width, h = image.height
        guard w > 2, h > 2, w <= 2048, h <= 2048,
              image.pixels.count == w * h, region.isValid,
              settings.minimumDiameter.isFinite, settings.maximumDiameter.isFinite,
              settings.sensitivity.isFinite,
              settings.minimumDiameter > 0,
              settings.maximumDiameter >= settings.minimumDiameter,
              settings.maximumDiameter <= 1, grid?.isValid != false else { return [] }
        let short = Double(min(w, h))
        let minD = max(3, settings.minimumDiameter * short)
        let maxD = max(minD, settings.maximumDiameter * short)
        let window = max(8, Int(maxD * 0.9))
        let threshold = 3 + (1 - min(1, max(0, settings.sensitivity))) * 32
        let stride = w + 1
        var integral = [Int](repeating: 0, count: (w + 1) * (h + 1))
        for y in 0..<h {
            var rowSum = 0
            for x in 0..<w {
                rowSum += Int(image.pixels[y * w + x])
                integral[(y + 1) * stride + x + 1] = integral[y * stride + x + 1] + rowSum
            }
        }
        var mask = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            let top = max(0, y - window), bottom = min(h, y + window + 1)
            for x in 0..<w {
                let left = max(0, x - window), right = min(w, x + window + 1)
                let sum = integral[bottom * stride + right] - integral[top * stride + right]
                    - integral[bottom * stride + left] + integral[top * stride + left]
                let mean = Double(sum) / Double((bottom - top) * (right - left))
                let pixel = Double(image.pixels[y * w + x])
                let contrast = settings.brightCells ? pixel - mean : mean - pixel
                if contrast > threshold { mask[y * w + x] = 1 }
            }
        }
        // Remove long straight runs (ruling lines) before component labeling.
        // Read from an unchanged mask so crossing lines are handled symmetrically.
        let source = mask
        let lineLimit = max(16, Int(maxD * 2.5))
        for y in 0..<h {
            var start = 0
            while start < w {
                if source[y * w + start] == 0 { start += 1; continue }
                var end = start + 1
                while end < w && source[y * w + end] == 1 { end += 1 }
                if end - start > lineLimit {
                    for x in start..<end { mask[y * w + x] = 0 }
                }
                start = end
            }
        }
        for x in 0..<w {
            var start = 0
            while start < h {
                if source[start * w + x] == 0 { start += 1; continue }
                var end = start + 1
                while end < h && source[end * w + x] == 1 { end += 1 }
                if end - start > lineLimit {
                    for y in start..<end { mask[y * w + x] = 0 }
                }
                start = end
            }
        }
        var markers: [CellMarker] = []
        var queue: [Int] = []
        // Label full-image objects, then filter centers by ROI. Cropping first
        // would create artificial partial objects on the ROI border.
        for seed in 0..<(w * h) where mask[seed] == 1 {
            queue.removeAll(keepingCapacity: true)
            queue.append(seed); mask[seed] = 0
            var head = 0, sumX = 0, sumY = 0
            var minX = w, maxX = 0, minY = h, maxY = 0
            while head < queue.count {
                let index = queue[head]; head += 1
                let x = index % w, y = index / w
                sumX += x; sumY += y
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                for ny in max(0, y - 1)...min(h - 1, y + 1) {
                    for nx in max(0, x - 1)...min(w - 1, x + 1) {
                        let next = ny * w + nx
                        if mask[next] == 1 { mask[next] = 0; queue.append(next) }
                    }
                }
            }
            let bw = Double(maxX - minX + 1), bh = Double(maxY - minY + 1)
            let diameter = max(bw, bh)
            let fill = Double(queue.count) / (bw * bh)
            let singleObject = diameter <= maxD && max(bw / bh, bh / bw) < 2.4
            // Connected clumps remain one object; no watershed or splitting.
            let clump = diameter <= maxD * 3 && max(bw / bh, bh / bw) < 5 && fill >= 0.3
            guard diameter >= minD, singleObject || clump, fill >= 0.16,
                  Double(queue.count) >= .pi * pow(minD / 2, 2) * 0.22 else { continue }
            let x = (Double(sumX) / Double(queue.count) + 0.5) / Double(w)
            let y = (Double(sumY) / Double(queue.count) + 0.5) / Double(h)
            let extent = CountRegion(x: Double(minX) / Double(w), y: Double(minY) / Double(h),
                width: bw / Double(w), height: bh / Double(h))
            let marker = CellMarker(x: x, y: y, radius: diameter / short / 2 + 0.002, extent: extent)
            let layout = grid ?? NeubauerGrid(mode: .custom)
            guard layout.assignedIndex(for: marker, in: region) != nil else { continue }
            markers.append(marker)
        }
        return markers.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
    }
}
