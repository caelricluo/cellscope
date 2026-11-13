import AppKit
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(srgbRed: 0.09, green: 0.18, blue: 0.16, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let mint = NSColor(srgbRed: 0.78, green: 0.93, blue: 0.57, alpha: 1)
mint.setStroke()
for (x, y, dx, dy) in [(230.0,230.0,1.0,1.0),(794,230,-1,1),(230,794,1,-1),(794,794,-1,-1)] {
    let path = NSBezierPath(); path.lineWidth = 26; path.lineCapStyle = .round; path.lineJoinStyle = .round
    path.move(to: NSPoint(x:x,y:y+dy*100)); path.line(to:NSPoint(x:x,y:y)); path.line(to:NSPoint(x:x+dx*100,y:y)); path.stroke()
}
for (x,y,r) in [(410.0,560.0,100.0),(620,415,75),(630,660,47)] {
    let path = NSBezierPath(ovalIn: NSRect(x:x-r,y:y-r,width:r*2,height:r*2))
    path.lineWidth = 16; path.stroke()
    mint.withAlphaComponent(0.12).setFill(); path.fill()
    mint.setFill(); NSBezierPath(ovalIn:NSRect(x:x-13,y:y-13,width:26,height:26)).fill()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using:.png,properties:[:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
