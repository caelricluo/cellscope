import SwiftUI
import UIKit

struct ImageCanvas: UIViewRepresentable {
    @ObservedObject var model: CounterModel
    func makeUIView(context: Context) -> MicroscopeScrollView {
        let view = MicroscopeScrollView()
        view.onTap = { x, y in model.tap(x: x, y: y) }
        view.onRegion = { model.updateRegion($0) }
        return view
    }
    func updateUIView(_ view: MicroscopeScrollView, context: Context) {
        view.configure(image: model.image, markers: model.markers, region: model.region,
                       mode: model.mode, busy: model.isDetecting, grid: model.grid)
    }
}

final class MicroscopeScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let photo = AnnotationSurface()
    var onTap: ((Double, Double) -> Void)?
    var onRegion: ((CountRegion) -> Void)?
    private var currentImage: UIImage?
    private var mode: EditMode = .inspect
    private var startPoint: CGPoint?
    private var previousRegion = CountRegion()
    private var lastSize = CGSize.zero
    private var needsFit = true
    private var busy = false
    private lazy var selectPan = UIPanGestureRecognizer(target: self, action: #selector(selectRegion(_:)))

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self; backgroundColor = UIColor(white: 0.09, alpha: 1)
        showsHorizontalScrollIndicator = false; showsVerticalScrollIndicator = false
        bouncesZoom = true; contentInsetAdjustmentBehavior = .never
        addSubview(photo)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapImage(_:)))
        photo.addGestureRecognizer(tap)
        photo.isUserInteractionEnabled = true
        selectPan.delegate = self; photo.addGestureRecognizer(selectPan)
        accessibilityIdentifier = "imageCanvas"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(image: UIImage?, markers: [CellMarker], region: CountRegion, mode: EditMode, busy: Bool, grid: NeubauerGrid) {
        if currentImage !== image {
            currentImage = image; photo.image = image; needsFit = true
            zoomScale = 1
            photo.frame = CGRect(origin: .zero, size: image?.size ?? CGSize(width: 1, height: 1))
            contentSize = photo.bounds.size
        }
        self.mode = mode; self.busy = busy
        photo.markers = markers; photo.region = region; photo.grid = grid; photo.setNeedsDisplay()
        selectPan.isEnabled = mode == .region && !busy
        panGestureRecognizer.minimumNumberOfTouches = mode == .add || mode == .remove ? 2 : 1
        panGestureRecognizer.isEnabled = mode != .region
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        if let image = currentImage, bounds.width > 0, bounds.height > 0,
           needsFit || lastSize != bounds.size {
            lastSize = bounds.size; needsFit = false
            let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
            minimumZoomScale = fit; maximumZoomScale = fit * 8; zoomScale = fit
        }
        centerPhoto()
    }
    private func centerPhoto() {
        photo.center = CGPoint(x: max(contentSize.width, bounds.width) / 2,
                               y: max(contentSize.height, bounds.height) / 2)
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { photo }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerPhoto() }
    @objc private func tapImage(_ gesture: UITapGestureRecognizer) {
        guard !busy else { return }
        let point = gesture.location(in: photo)
        onTap?(point.x / photo.bounds.width, point.y / photo.bounds.height)
    }
    @objc private func selectRegion(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: photo)
        let p = CGPoint(x: min(1, max(0, location.x / photo.bounds.width)),
                        y: min(1, max(0, location.y / photo.bounds.height)))
        if gesture.state == .began { startPoint = p; previousRegion = photo.region }
        guard let startPoint else { return }
        let region = CountRegion(x: min(startPoint.x, p.x), y: min(startPoint.y, p.y),
                                 width: abs(startPoint.x - p.x), height: abs(startPoint.y - p.y))
        if gesture.state == .changed { photo.region = region; photo.setNeedsDisplay() }
        if gesture.state == .ended {
            if region.width >= 0.04 && region.height >= 0.04 { onRegion?(region) }
            else { photo.region = previousRegion; photo.setNeedsDisplay() }
            self.startPoint = nil
        }
        if gesture.state == .cancelled || gesture.state == .failed {
            photo.region = previousRegion; photo.setNeedsDisplay(); self.startPoint = nil
        }
    }
}

final class AnnotationSurface: UIView {
    var image: UIImage?
    var markers: [CellMarker] = []
    var region = CountRegion()
    var grid = NeubauerGrid()
    override func draw(_ rect: CGRect) {
        guard let image, let c = UIGraphicsGetCurrentContext() else { return }
        image.draw(in: bounds)
        GridDrawing.draw(in: c, size: bounds.size, region: region, grid: grid)
        let short = min(bounds.width, bounds.height)
        for (index, marker) in markers.enumerated() {
            let p = CGPoint(x: marker.x * bounds.width, y: marker.y * bounds.height)
            let radius = marker.radius * short
            let color = marker.isManual ? UIColor.systemOrange : UIColor(red: 0.05, green: 0.65, blue: 0.47, alpha: 1)
            c.setStrokeColor(color.cgColor); c.setLineWidth(short * 0.0025)
            c.strokeEllipse(in: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
            ("\(index + 1)" as NSString).draw(at: CGPoint(x: p.x + radius, y: p.y - radius), withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: short * 0.015, weight: .bold), .foregroundColor: color
            ])
        }
    }
}
