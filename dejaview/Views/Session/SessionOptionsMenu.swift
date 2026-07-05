import SwiftUI

/// Floating Liquid Glass options button (bottom-right of the session).
///
/// The option buttons morph in and out of the main button using
/// the standard Liquid Glass animation (`GlassEffectContainer` + `glassEffectID`).
struct SessionOptionsMenu<Session: RemoteSessionControlling>: View {
    @ObservedObject var session: Session

    @State private var isExpanded = false
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(alignment: .trailing, spacing: 14) {
                if isExpanded {
                    ForEach(RemoteSessionQuality.allCases) { quality in
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
