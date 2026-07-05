import SwiftUI

// Liquid Glass helpers with graceful fallbacks for iOS < 26.

extension View {
    /// Applies a Liquid Glass effect in the given shape (iOS 26+),
    /// falling back to an ultra-thin material on older systems.
    @ViewBuilder
    func liquidGlass(in shape: some Shape, isInteractive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if isInteractive {
                self.glassEffect(.regular.interactive(), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Glass panel container for non-toolbar connect surfaces.
    func glassPanel(cornerRadius: CGFloat = 24, isInteractive: Bool = false) -> some View {
        self.liquidGlass(in: RoundedRectangle(cornerRadius: cornerRadius),
                         isInteractive: isInteractive)
    }

    /// Prominent glass button (iOS 26+), bordered-prominent fallback.
    @ViewBuilder
    func prominentGlassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Regular glass button (iOS 26+), bordered fallback.
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Card container used on the connect screen.
    func cardStyle() -> some View {
        self
            .padding(20)
            .glassPanel(cornerRadius: 28)
    }
}
