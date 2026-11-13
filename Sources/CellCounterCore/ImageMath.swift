import Foundation

enum ImageMath {
    static func gaussian(_ pixels: [Float], width: Int, height: Int, sigma: Double) -> [Float] {
        let radius = max(1, Int(ceil(sigma * 3)))
        var kernel = (-radius...radius).map { Float(exp(-Double($0 * $0) / (2 * sigma * sigma))) }
        let sum = kernel.reduce(0, +)
        for i in kernel.indices { kernel[i] /= sum }
        var horizontal = [Float](repeating: 0, count: pixels.count)
        var output = horizontal
        for y in 0..<height {
            for x in 0..<width {
                var value: Float = 0
                for k in -radius...radius { value += pixels[y * width + min(width - 1, max(0, x + k))] * kernel[k + radius] }
                horizontal[y * width + x] = value
            }
        }
        for y in 0..<height {
            for x in 0..<width {
                var value: Float = 0
                for k in -radius...radius { value += horizontal[min(height - 1, max(0, y + k)) * width + x] * kernel[k + radius] }
                output[y * width + x] = value
            }
        }
        return output
    }
    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
    static func closingCross(_ mask: [UInt8], width: Int, height: Int) -> [UInt8] {
        var expanded = mask, output = mask
        for y in 1..<(height - 1) { for x in 1..<(width - 1) {
            let p = y * width + x
            expanded[p] = max(mask[p], mask[p-1], mask[p+1], mask[p-width], mask[p+width])
        } }
        for y in 1..<(height - 1) { for x in 1..<(width - 1) {
            let p = y * width + x
            output[p] = min(expanded[p], expanded[p-1], expanded[p+1], expanded[p-width], expanded[p+width])
        } }
        return output
    }
}
