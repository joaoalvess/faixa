import SwiftUI

struct CapsuleSlider: View {
    let fraction: Double
    let height: CGFloat
    var onChange: (Double) -> Void = { _ in }
    var onCommit: (Double) -> Void = { _ in }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.25))
                Rectangle()
                    .fill(.white)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
            .clipShape(Capsule())
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { onChange(value(at: $0.location.x, width: geometry.size.width)) }
                    .onEnded { onCommit(value(at: $0.location.x, width: geometry.size.width)) }
            )
        }
        .frame(height: height)
    }

    private func value(at x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return min(max(x / width, 0), 1)
    }
}
