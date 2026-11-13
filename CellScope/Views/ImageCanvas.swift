import SwiftUI
import UIKit

struct ImageCanvas: UIViewRepresentable {
    @ObservedObject var model: CounterModel
    var modeOverride: EditMode? = nil
    func makeUIView(context: Context) -> MicroscopeScrollView {
        let view = MicroscopeScrollView()
        view.onTap = { x, y in if modeOverride == nil { model.tap(x: x, y: y) } }
        view.onFrame = { model.updateFrame($0) }
        view.onHandle = { model.activeHandle = $0 }
        return view
    }
    func updateUIView(_ view: MicroscopeScrollView, context: Context) {
        view.configure(image: model.image, markers: model.markers, region: model.region,
            mode: modeOverride ?? model.mode, busy: model.isDetecting, locating: model.isLocatingGrid,
            grid: model.grid, alignment: model.alignment, showLabels: model.showMarkerLabels, handle: model.activeHandle)
    }
}

final class MicroscopeScrollView: UIScrollView, UIScrollViewDelegate {
    let photo = AnnotationSurface()
    private let frameEditor = FrameHandleOverlay()
    var onTap: ((Double, Double) -> Void)?
    var onFrame: ((GridQuad) -> Void)?
    var onHandle: ((GridHandle) -> Void)?
    private var currentImage: UIImage?
    private var mode: EditMode = .inspect
    private var lastSize = CGSize.zero
    private var needsFit = true
    private var busy = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self; backgroundColor = UIColor(white: 0.09, alpha: 1)
        showsHorizontalScrollIndicator = false; showsVerticalScrollIndicator = false
        bouncesZoom = true; contentInsetAdjustmentBehavior = .never
        addSubview(photo); addSubview(frameEditor)
        frameEditor.photo = photo
        frameEditor.onFrame = { [weak self] quad in self?.onFrame?(quad) }
        frameEditor.onHandle = { [weak self] handle in self?.onHandle?(handle) }
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapImage(_:)))
        photo.addGestureRecognizer(tap); photo.isUserInteractionEnabled = true
        accessibilityIdentifier = "imageCanvas"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(image: UIImage?, markers: [CellMarker], region: CountRegion, mode: EditMode, busy: Bool,
                   locating: Bool, grid: NeubauerGrid, alignment: GridQuad?, showLabels: Bool, handle: GridHandle) {
        if currentImage !== image {
            currentImage = image; photo.image = image; needsFit = true
            zoomScale = 1
            photo.frame = CGRect(origin: .zero, size: image?.size ?? CGSize(width: 1, height: 1))
            contentSize = photo.bounds.size
        }
        self.mode = mode; self.busy = busy
        photo.markers = markers; photo.region = region; photo.grid = grid; photo.alignment = alignment
        photo.showLabels = showLabels; photo.setNeedsDisplay()
        frameEditor.quad = alignment ?? GridQuad(region: region); frameEditor.selected = handle
        frameEditor.isHidden = mode != .region || image == nil
        frameEditor.isUserInteractionEnabled = !locating
        // In frame mode one finger edits, two fingers move/zoom the image.
        panGestureRecognizer.minimumNumberOfTouches = mode == .inspect ? 1 : 2
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        if let image = currentImage, bounds.width > 0, bounds.height > 0, needsFit || lastSize != bounds.size {
            lastSize = bounds.size; needsFit = false
            let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
            minimumZoomScale = fit; maximumZoomScale = fit * 12; zoomScale = fit
        }
        photo.center = CGPoint(x: max(contentSize.width, bounds.width) / 2, y: max(contentSize.height, bounds.height) / 2)
        // Keep touch targets in viewport points, independent of image zoom.
        frameEditor.frame = bounds; bringSubviewToFront(frameEditor)
        frameEditor.refresh()
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { photo }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { setNeedsLayout() }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { setNeedsLayout() }
    @objc private func tapImage(_ gesture: UITapGestureRecognizer) {
        guard !busy else { return }
        let point = gesture.location(in: photo)
        onTap?(point.x / photo.bounds.width, point.y / photo.bounds.height)
    }
}

/// Fixed-size touch targets, perspective-preserving drags, and a loupe above
/// the finger. Drag deltas are converted through the current image transform.
private final class FrameHandleOverlay: UIView {
    weak var photo: AnnotationSurface?
    var quad = GridQuad(region: CountRegion())
    var selected: GridHandle = .move
    var onFrame: ((GridQuad) -> Void)?
    var onHandle: ((GridHandle) -> Void)?
    private var dragHandle: GridHandle?
    private var startQuad: GridQuad?
    private var startPoint = CGPoint.zero
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(dragFrame(_:)))
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear; isOpaque = false
        pan.maximumNumberOfTouches = 1; addGestureRecognizer(pan)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectHandle(_:))))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func point(_ p: GridPoint) -> CGPoint {
        guard let photo else { return .zero }
        return photo.convert(CGPoint(x:p.x*photo.bounds.width,y:p.y*photo.bounds.height),to:self)
    }
    private func path() -> UIBezierPath {
        let p = UIBezierPath(); p.move(to:point(quad.topLeft))
        for c in quad.corners.dropFirst() { p.addLine(to:point(c)) }; p.close(); return p
    }
    private func target(at p: CGPoint) -> GridHandle? {
        let handles = GridHandle.allCases.filter{$0 != .move}
        if let nearest = handles.min(by: { distance(p,point($0.point(in:quad))) < distance(p,point($1.point(in:quad))) }),
           distance(p,point(nearest.point(in:quad))) <= 28 { return nearest }
        // Also grab anywhere along a side, not just its middle handle.
        let c = quad.corners.map(point)
        for (i,h) in [GridHandle.top,.right,.bottom,.left].enumerated() {
            let a = c[i], b = c[(i+1)%4], dx = b.x-a.x, dy = b.y-a.y
            let t = min(1,max(0,((p.x-a.x)*dx+(p.y-a.y)*dy)/max(1,dx*dx+dy*dy)))
            if distance(p,CGPoint(x:a.x+t*dx,y:a.y+t*dy)) <= 20 { return h }
        }
        return path().contains(p) ? .move : nil
    }
    private func distance(_ a:CGPoint,_ b:CGPoint)->CGFloat { hypot(a.x-b.x,a.y-b.y) }
    override func point(inside p: CGPoint, with event: UIEvent?) -> Bool { !isHidden && target(at:p) != nil }
    func refresh() {
        setNeedsDisplay()
        accessibilityElements = GridHandle.allCases.filter{$0 != .move}.map { handle in
            let e = UIAccessibilityElement(accessibilityContainer:self), p = point(handle.point(in:quad))
            e.accessibilityLabel = handle.title; e.accessibilityIdentifier = "frameHandle-\(handle.rawValue)"
            e.accessibilityTraits = .button
            e.accessibilityFrameInContainerSpace = CGRect(x:p.x-22,y:p.y-22,width:44,height:44)
            return e
        }
    }
    @objc private func selectHandle(_ g: UITapGestureRecognizer) {
        if let handle = target(at:g.location(in:self)) { selected = handle; onHandle?(handle); refresh() }
    }
    @objc private func dragFrame(_ g: UIPanGestureRecognizer) {
        guard let photo else { return }
        if g.state == .began {
            dragHandle = target(at:g.location(in:self)); startQuad = quad; startPoint = g.location(in:photo)
            if let dragHandle { selected = dragHandle; onHandle?(dragHandle) }
        }
        guard let handle = dragHandle, let startQuad else { return }
        if g.state == .changed || g.state == .ended {
            let p = g.location(in:photo)
            quad = startQuad.adjusting(handle,dx:(p.x-startPoint.x)/photo.bounds.width,dy:(p.y-startPoint.y)/photo.bounds.height)
            photo.alignment = quad; photo.region = quad.bounds; photo.setNeedsDisplay()
            onFrame?(quad); refresh()
        }
        if g.state == .cancelled || g.state == .failed { quad = startQuad; onFrame?(startQuad) }
        if [.ended,.cancelled,.failed].contains(g.state) { dragHandle = nil; self.startQuad = nil; refresh() }
    }
    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext(), !isHidden else { return }
        let green = UIColor(red:0.12,green:0.9,blue:0.65,alpha:1)
        green.setStroke(); let outline = path(); outline.lineWidth = 2; outline.stroke()
        for h in GridHandle.allCases where h != .move {
            let p = point(h.point(in:quad)), r:CGFloat = h == selected ? 9 : 7
            c.setFillColor((h == selected ? green : UIColor.white).cgColor)
            c.fillEllipse(in:CGRect(x:p.x-r,y:p.y-r,width:r*2,height:r*2))
            c.setStrokeColor(green.cgColor); c.setLineWidth(2)
            c.strokeEllipse(in:CGRect(x:p.x-r,y:p.y-r,width:r*2,height:r*2))
        }
        guard let handle = dragHandle, let photo, let image = photo.image else { return }
        let q = handle.point(in:quad), anchor = point(q), side:CGFloat = 110
        let x = min(max(4,anchor.x-side/2),max(4,bounds.width-side-4))
        let y = anchor.y > side+45 ? anchor.y-side-38 : min(bounds.height-side-4,anchor.y+45)
        let loupe = CGRect(x:x,y:max(4,y),width:side,height:side)
        c.saveGState(); UIBezierPath(roundedRect:loupe,cornerRadius:18).addClip()
        UIColor.black.setFill(); c.fill(loupe)
        let a = photo.convert(CGPoint.zero,to:self), b = photo.convert(CGPoint(x:1,y:0),to:self)
        let scale = max(0.01,abs(b.x-a.x))*3
        image.draw(in:CGRect(x:loupe.midX-q.x*image.size.width*scale,y:loupe.midY-q.y*image.size.height*scale,
            width:image.size.width*scale,height:image.size.height*scale))
        c.setStrokeColor(green.cgColor); c.setLineWidth(1)
        c.move(to:CGPoint(x:loupe.midX-18,y:loupe.midY)); c.addLine(to:CGPoint(x:loupe.midX+18,y:loupe.midY))
        c.move(to:CGPoint(x:loupe.midX,y:loupe.midY-18)); c.addLine(to:CGPoint(x:loupe.midX,y:loupe.midY+18)); c.strokePath()
        c.restoreGState(); UIColor.white.setStroke(); let border = UIBezierPath(roundedRect:loupe,cornerRadius:18); border.lineWidth = 3; border.stroke()
    }
}

final class AnnotationSurface: UIView {
    var image: UIImage?
    var markers: [CellMarker] = []
    var region = CountRegion()
    var grid = NeubauerGrid()
    var alignment: GridQuad?
    var showLabels = false
    override func draw(_ rect: CGRect) {
        guard let image, let c = UIGraphicsGetCurrentContext() else { return }
        image.draw(in: bounds)
        GridDrawing.draw(in:c,size:bounds.size,region:region,grid:grid,alignment:alignment)
        let short = min(bounds.width,bounds.height)
        for (index,marker) in markers.enumerated() {
            let p = CGPoint(x:marker.x*bounds.width,y:marker.y*bounds.height), radius = marker.radius*short
            let color = marker.isManual ? UIColor.systemOrange : UIColor(red:0.05,green:0.65,blue:0.47,alpha:1)
            c.setStrokeColor(color.cgColor); c.setLineWidth(short*0.0012)
            c.strokeEllipse(in:CGRect(x:p.x-radius,y:p.y-radius,width:radius*2,height:radius*2))
            if showLabels { ("\(index+1)" as NSString).draw(at:CGPoint(x:p.x+radius,y:p.y-radius),withAttributes:[
                .font:UIFont.monospacedDigitSystemFont(ofSize:short*0.008,weight:.bold),.foregroundColor:color]) }
        }
    }
}
