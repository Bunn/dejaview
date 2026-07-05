import SwiftUI

extension View {
    /// Applies a Liquid Glass effect in the given shape.
    func liquidGlass(in shape: some Shape, isInteractive: Bool = true) -> some View {
        if isInteractive {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.glassEffect(.regular, in: shape)
        }
    }

    /// Glass panel container for non-toolbar connect surfaces.
    func glassPanel(cornerRadius: CGFloat = 24, isInteractive: Bool = false) -> some View {
        self.liquidGlass(in: RoundedRectangle(cornerRadius: cornerRadius),
                         isInteractive: isInteractive)
    }

    /// Card container used on the connect screen.
    func cardStyle() -> some View {
        self
            .padding(20)
            .glassPanel(cornerRadius: 28)
    }
}
