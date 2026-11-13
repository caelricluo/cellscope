// macOS diagnostic runner using the same CoreGraphics grayscale conversion as the app.
// swiftc -O Sources/cellscopeCore/*.swift scripts/analyze_image.swift -o /tmp/cellscope-analyze
// /tmp/cellscope-analyze image.jpg result.json [redBloodCells|overview|singleLarge|custom]
import Foundation
import CoreGraphics
import ImageIO

@main struct AnalyzeImage {
    static func main() throws {
        guard CommandLine.arguments.count >= 3 else {
            throw NSError(domain:"cellscope",code:1,userInfo:[NSLocalizedDescriptionKey:"Usage: analyze image.jpg result.json [mode]"])
        }
        let sourceURL = URL(fileURLWithPath:CommandLine.arguments[1])
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL,nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,
                kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:1600] as CFDictionary) else {
            throw NSError(domain:"cellscope",code:2,userInfo:[NSLocalizedDescriptionKey:"Cannot decode image"])
        }
        let w = cg.width,h = cg.height
        var pixels = [UInt8](repeating:0,count:w*h)
        let success = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let c = CGContext(data:bytes.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w,
                space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue) else { return false }
            c.draw(cg,in:CGRect(x:0,y:0,width:w,height:h)); return true
        }
        guard success else { throw CocoaError(.fileReadCorruptFile) }
        let image = GrayImage(width:w,height:h,pixels:pixels), located = GridDetector.detect(image)
        let mode = CommandLine.arguments.count > 3 ? CountingMode(rawValue:CommandLine.arguments[3]) ?? .redBloodCells : .redBloodCells
        let quad = mode == .custom ? located.central ?? located.corner ?? located.overview : located.alignment(for:mode)
        let region = quad?.bounds ?? CountRegion()
        let report = quad.map { CellDetector.analyze(image,region:region,settings:mode.detectionSettings,grid:NeubauerGrid(mode:mode),alignment:$0) }
        let all = quad.map { CellDetector.analyze(image,region:region,settings:mode.detectionSettings,alignment:$0) }
        func json<T:Encodable>(_ value:T) throws -> Any { try JSONSerialization.jsonObject(with:JSONEncoder().encode(value),options:.fragmentsAllowed) }
        let output:[String:Any] = ["width":w,"height":h,"mode":mode.rawValue,"status":located.summary,
            "central":try json(located.central),"overview":try json(located.overview),"corner":try json(located.corner),
            "alignment":try json(quad),"markers":try json(report?.markers ?? []),"allMarkers":try json(all?.markers ?? []),
            "count":report?.markers.count as Any? ?? NSNull(),"allCount":all?.markers.count as Any? ?? NSNull(),
            "estimatedDiameterPixels":report?.estimatedDiameterPixels as Any? ?? NSNull()]
        try JSONSerialization.data(withJSONObject:output,options:[.prettyPrinted,.sortedKeys,.fragmentsAllowed])
            .write(to:URL(fileURLWithPath:CommandLine.arguments[2]),options:.atomic)
        print(located.summary,"count:",report?.markers.count as Any,"whole reference:",all?.markers.count as Any)
    }
}
