import AppKit

final class MarqueeLabel: NSView {
    let width: CGFloat
    private let gap: CGFloat = 25
    private let pointsPerSecond: CGFloat = 25
    private let systemBaselineOffset: CGFloat = 1.5
    private let fadeWidth: CGFloat = 8
    private let font = NSFont.menuBarFont(ofSize: 0)
    private let stripLayer = CALayer()
    private let fadeLayer = CAGradientLayer()
    private var text = ""
    private var isScrolling = false
    private var textWidth: CGFloat = 0

    private var loopDistance: CGFloat {
        textWidth + gap
    }

    private var copyCount: Int {
        isScrolling ? Int(ceil(width / loopDistance)) + 1 : 1
    }

    private var stripSize: NSSize {
        NSSize(width: CGFloat(copyCount - 1) * loopDistance + textWidth, height: ceil(font.ascender - font.descender))
    }

    init(width: CGFloat) {
        self.width = width
        super.init(frame: .zero)
        fadeLayer.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
        fadeLayer.startPoint = CGPoint(x: 0, y: 0.5)
        fadeLayer.endPoint = CGPoint(x: 1, y: 0.5)
        let hostLayer = CALayer()
        hostLayer.addSublayer(stripLayer)
        hostLayer.mask = fadeLayer
        layer = hostLayer
        wantsLayer = true
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(text newText: String, isScrolling shouldScroll: Bool) {
        guard newText != text || shouldScroll != isScrolling else { return }
        if newText != text {
            text = newText
            textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        }
        isScrolling = shouldScroll
        redrawStrip()
        restartAnimation()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let size = stripSize
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stripLayer.frame = CGRect(
            x: 0,
            y: ((bounds.height - size.height) / 2).rounded() - systemBaselineOffset,
            width: size.width,
            height: size.height
        )
        let fade = bounds.width > 0 ? min(fadeWidth / bounds.width, 0.5) : 0
        let leadingFade = isScrolling ? fade : 0
        let trailingFade = isScrolling || textWidth > width ? fade : 0
        fadeLayer.frame = bounds
        fadeLayer.locations = [0, leadingFade, 1 - trailingFade, 1].map { NSNumber(value: Double($0)) }
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        redrawStrip()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        redrawStrip()
    }

    private func redrawStrip() {
        let size = stripSize
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        guard size.width > 0,
              let bitmap = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: Int(ceil(size.width * scale)),
                  pixelsHigh: Int(ceil(size.height * scale)),
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: 0,
                  bitsPerPixel: 0
              )
        else {
            stripLayer.contents = nil
            return
        }
        bitmap.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
            for index in 0..<copyCount {
                (text as NSString).draw(at: NSPoint(x: CGFloat(index) * loopDistance, y: -font.descender), withAttributes: attributes)
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        stripLayer.contents = bitmap.cgImage
        stripLayer.contentsScale = scale
        needsLayout = true
    }

    private func restartAnimation() {
        stripLayer.removeAnimation(forKey: "marquee")
        guard isScrolling else { return }

        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = -loopDistance
        animation.duration = loopDistance / pointsPerSecond
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        stripLayer.add(animation, forKey: "marquee")
    }
}
