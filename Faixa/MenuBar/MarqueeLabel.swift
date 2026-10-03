import AppKit

final class MarqueeLabel: NSView {
    private let maxWidth: CGFloat
    private let gap: CGFloat = 25
    private let pointsPerSecond: CGFloat = 25
    private let font = NSFont.menuBarFont(ofSize: 0)
    private let stripLayer = CALayer()
    private var text = ""
    private var isScrolling = false
    private var textWidth: CGFloat = 0

    var displayedWidth: CGFloat {
        min(textWidth, maxWidth)
    }

    private var overflows: Bool {
        textWidth > maxWidth
    }

    private var stripSize: NSSize {
        NSSize(width: overflows ? textWidth * 2 + gap : textWidth, height: ceil(font.ascender - font.descender))
    }

    init(maxWidth: CGFloat) {
        self.maxWidth = maxWidth
        super.init(frame: .zero)
        let hostLayer = CALayer()
        hostLayer.masksToBounds = true
        hostLayer.addSublayer(stripLayer)
        layer = hostLayer
        wantsLayer = true
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
            redrawStrip()
        }
        isScrolling = shouldScroll
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
        stripLayer.frame = CGRect(x: 0, y: ((bounds.height - size.height) / 2).rounded(), width: size.width, height: size.height)
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
            let origins: [CGFloat] = overflows ? [0, textWidth + gap] : [0]
            for x in origins {
                (text as NSString).draw(at: NSPoint(x: x, y: -font.descender), withAttributes: attributes)
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        stripLayer.contents = bitmap.cgImage
        stripLayer.contentsScale = scale
        needsLayout = true
    }

    private func restartAnimation() {
        stripLayer.removeAnimation(forKey: "marquee")
        guard isScrolling, overflows else { return }

        let distance = textWidth + gap
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = -distance
        animation.duration = distance / pointsPerSecond
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        stripLayer.add(animation, forKey: "marquee")
    }
}
