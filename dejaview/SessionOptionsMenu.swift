import SwiftUI

/// Floating Liquid Glass options button (bottom-right of the session).
///
/// On iOS 26+ the option buttons morph in and out of the main button using
/// the standard Liquid Glass animation (`GlassEffectContainer` +
/// `glassEffectID`). Older systems get a material fallback with a spring
/// transition.
struct SessionOptionsMenu: View {
    @ObservedObject var session: VNCSession

    @State private var isExpanded = false
    @Namespace private var glassNamespace

    var body: some View {
        if #available(iOS 26.0, *) {
            modernMenu
        } else {
            legacyMenu
        }
    }

    // MARK: - iOS 26+: Liquid Glass morph

    @available(iOS 26.0, *)
    private var modernMenu: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(alignment: .trailing, spacing: 14) {
                if isExpanded {
                    ForEach(VNCSession.Quality.allCases) { quality in
                        optionRow(title: quality.rawValue,
                                  icon: quality.icon,
                                  isSelected: session.quality == quality) {
                            session.setQuality(quality)
                            collapse()
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .glassEffectID(quality.rawValue, in: glassNamespace)
                    }

                    optionRow(title: "Trackpad Mode",
                              icon: "cursorarrow.motionlines",
                              isSelected: session.touchMode == .trackpad) {
                        session.toggleTouchMode()
                        collapse()
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("trackpad", in: glassNamespace)

                    optionRow(title: "Clipboard Sync",
                              icon: "doc.on.clipboard",
                              isSelected: session.isClipboardSyncEnabled) {
                        session.toggleClipboardSync()
                        collapse()
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("clipboard", in: glassNamespace)
                }

                mainButton
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("menu", in: glassNamespace)
            }
        }
        .animation(.smooth(duration: 0.4), value: isExpanded)
    }

    // MARK: - iOS 17–18 fallback

    private var legacyMenu: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if isExpanded {
                Group {
                    ForEach(VNCSession.Quality.allCases) { quality in
                        optionRow(title: quality.rawValue,
                                  icon: quality.icon,
                                  isSelected: session.quality == quality) {
                            session.setQuality(quality)
                            collapse()
                        }
                        .background(.ultraThinMaterial, in: Capsule())
                    }

                    optionRow(title: "Trackpad Mode",
                              icon: "cursorarrow.motionlines",
                              isSelected: session.touchMode == .trackpad) {
                        session.toggleTouchMode()
                        collapse()
                    }
                    .background(.ultraThinMaterial, in: Capsule())

                    optionRow(title: "Clipboard Sync",
                              icon: "doc.on.clipboard",
                              isSelected: session.isClipboardSyncEnabled) {
                        session.toggleClipboardSync()
                        collapse()
                    }
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .transition(.scale(scale: 0.6, anchor: .bottomTrailing)
                    .combined(with: .opacity))
            }

            mainButton
                .background(.ultraThinMaterial, in: Circle())
        }
        .animation(.spring(duration: 0.35), value: isExpanded)
    }

    // MARK: - Pieces

    private var mainButton: some View {
        Button {
            isExpanded.toggle()
        } label: {
            Image(systemName: isExpanded ? "xmark" : "slider.horizontal.3")
                .font(.body.weight(.medium))
                .frame(width: 52, height: 52)
                .contentShape(Circle())
        }
        .foregroundStyle(.white)
    }

    private func optionRow(title: String,
                           icon: String,
                           isSelected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 22)

                Text(title)
                    .font(.subheadline.weight(.medium))

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .contentShape(Capsule())
        }
    }

    private func collapse() {
        isExpanded = false
    }
}
