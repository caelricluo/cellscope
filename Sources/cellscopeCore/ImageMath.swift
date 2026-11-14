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
            if Task.isCancelled { return output }
            for x in 0..<width {
                var value: Float = 0
                for k in -radius...radius { value += pixels[y * width + min(width - 1, max(0, x + k))] * kernel[k + radius] }
                horizontal[y * width + x] = value
            }
        }
        for y in 0..<height {
            if Task.isCancelled { return output }
            for x in 0..<width {
                var value: Float = 0
                for k in -radius...radius { value += horizontal[min(height - 1, max(0, y + k)) * width + x] * kernel[k + radius] }
                output[y * width + x] = value
            }
        }
        return output
    }
    @inline(__always) static func median5(_ aa:Float,_ bb:Float,_ cc:Float,_ dd:Float,_ ee:Float)->Float {
        var a = aa, b = bb, c = cc, d = dd, e = ee
        if a > b { swap(&a,&b) }; if d > e { swap(&d,&e) }
        if a > c { swap(&a,&c) }; if b > c { swap(&b,&c) }
        if a > d { swap(&a,&d) }; if c > d { swap(&c,&d) }
        if b > e { swap(&b,&e) }; if b > c { swap(&b,&c) }
        return min(c,e)
    }
    /// Robust signed-response MAD, sampled before polarity clipping. Interpolation
    /// avoids threshold seams between tiles under uneven microscope illumination.
    static func localNoise(_ response:[Float],width:Int,height:Int)->[Float] {
        let tile = 64, columns = (width+63)/64, rows = (height+63)/64
        var levels = [Float](repeating:0.6,count:columns*rows)
        for ty in 0..<rows {
            if Task.isCancelled { return [Float](repeating:0,count:response.count) }
            for tx in 0..<columns {
                var values:[Double] = []
                for y in stride(from:ty*tile,to:min(height,(ty+1)*tile),by:3) {
                    for x in stride(from:tx*tile,to:min(width,(tx+1)*tile),by:3) {
                        values.append(Double(response[y*width+x]))
                    }
                }
                if values.count >= 12 {
                    let center = median(values)
                    levels[ty*columns+tx] = Float(1.4826*median(values.map{abs($0-center)}))
                }
            }
        }
        var output = [Float](repeating:0,count:width*height)
        for y in 0..<height {
            let yy = max(0,min(Double(rows-1),Double(y)/Double(tile)-0.5)), y0 = Int(yy), y1 = min(rows-1,y0+1), fy = Float(yy-Double(y0))
            for x in 0..<width {
                let xx = max(0,min(Double(columns-1),Double(x)/Double(tile)-0.5)), x0 = Int(xx), x1 = min(columns-1,x0+1), fx = Float(xx-Double(x0))
                output[y*width+x] = (1-fy)*((1-fx)*levels[y0*columns+x0]+fx*levels[y0*columns+x1]) +
                    fy*((1-fx)*levels[y1*columns+x0]+fx*levels[y1*columns+x1])
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
