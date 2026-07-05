import SwiftUI

/// Context menu for session options (bottom-right of the session).
struct SessionOptionsMenu<Session: RemoteSessionControlling>: View {
    // Safe to observe: framebuffer updates bypass objectWillChange (see
    // RemoteSessionControlling.imagePublisher), so this only re-renders on
    // actual state changes — which the menu checkmarks need to reflect.
    @ObservedObject var session: Session

    var body: some View {
        Menu {
            Picker("Quality", selection: qualityBinding) {
                ForEach(RemoteSessionQuality.allCases) { quality in
                    Label(quality.rawValue, systemImage: quality.icon)
                        .tag(quality)
                }
            }
            .pickerStyle(.inline)

            Toggle("Trackpad Mode", systemImage: "cursorarrow.motionlines",
                   isOn: trackpadBinding)

            Toggle("Clipboard Sync", systemImage: "doc.on.clipboard",
                   isOn: clipboardBinding)
        } label: {
            Label("Session Options", systemImage: "slider.horizontal.3")
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .foregroundStyle(.white)
        .accessibilityHint("Shows quality, trackpad, and clipboard options.")
    }

    private var qualityBinding: Binding<RemoteSessionQuality> {
        Binding {
            session.quality
        } set: { newQuality in
            session.setQuality(newQuality)
        }
    }

    // Idempotent setters: only toggle when the requested value actually
    // differs. SwiftUI may invoke a menu toggle's setter more than once per
    // tap, and a blind toggle() would cancel itself out.
    private var trackpadBinding: Binding<Bool> {
        Binding {
            session.touchMode == .trackpad
        } set: { isOn in
            if (session.touchMode == .trackpad) != isOn {
                session.toggleTouchMode()
            }
        }
    }

    private var clipboardBinding: Binding<Bool> {
        Binding {
            session.isClipboardSyncEnabled
        } set: { isOn in
            if session.isClipboardSyncEnabled != isOn {
                session.toggleClipboardSync()
            }
        }
    }
}
