import AppKit

final class MarqueeLabel: NSView {
    private let maxWidth: CGFloat
    private let gap: CGFloat = 25
    private let pointsPerSecond: CGFloat = 25
    private let strip = NSView()
    private let leadingLabel = NSTextField(labelWithString: "")
    private let trailingLabel = NSTextField(labelWithString: "")
    private var text = ""
    private var isScrolling = false
    private var textWidth: CGFloat = 0

    var displayedWidth: CGFloat {
        min(textWidth, maxWidth)
    }

    init(maxWidth: CGFloat) {
        self.maxWidth = maxWidth
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        strip.wantsLayer = true
        for label in [leadingLabel, trailingLabel] {
            label.font = .menuBarFont(ofSize: 0)
            label.textColor = .labelColor
            label.lineBreakMode = .byClipping
            strip.addSubview(label)
        }
        addSubview(strip)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(text newText: String, isScrolling shouldScroll: Bool) {
        guard newText != text || shouldScroll != isScrolling else { return }
        text = newText
        isScrolling = shouldScroll
        leadingLabel.stringValue = text
        trailingLabel.stringValue = text
        textWidth = ceil(leadingLabel.fittingSize.width)
        needsLayout = true
        layoutSubtreeIfNeeded()
        restartAnimation()
    }

    override func layout() {
        super.layout()
        let labelHeight = ceil(leadingLabel.fittingSize.height)
        let labelY = (bounds.height - labelHeight) / 2
        strip.frame = NSRect(x: 0, y: 0, width: textWidth * 2 + gap, height: bounds.height)
        leadingLabel.frame = NSRect(x: 0, y: labelY, width: textWidth, height: labelHeight)
        trailingLabel.frame = NSRect(x: textWidth + gap, y: labelY, width: textWidth, height: labelHeight)
        trailingLabel.isHidden = textWidth <= maxWidth
    }

    private func restartAnimation() {
        guard let layer = strip.layer else { return }
        layer.removeAnimation(forKey: "marquee")
        guard isScrolling, textWidth > maxWidth else { return }

        let distance = textWidth + gap
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = -distance
        animation.duration = distance / pointsPerSecond
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        layer.add(animation, forKey: "marquee")
    }
}
