import SwiftUI

struct SessionRemoteContent<Session: RemoteSessionControlling>: View {
    let session: Session
    let reconnectState: RemoteReconnectState?
    @Binding var zoomScale: CGFloat
    let followsCursor: Bool
    let acceptsHardwareKeyboardInput: Bool
    var acceptsPointerInput: Bool = true

    var body: some View {
        ZStack {
            RemoteDesktopView(session: session,
                              selectedFramebufferFrame: session.selectedDisplayFrame,
                              zoomScale: $zoomScale,
                              followsCursor: followsCursor,
                              acceptsHardwareKeyboardInput: acceptsHardwareKeyboardInput,
                              acceptsPointerInput: acceptsPointerInput)
                .id(session.displaySelection.id)
                .ignoresSafeArea()

            if let reconnectState {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                SessionReconnectOverlay(state: reconnectState,
                                        retryNow: session.retryConnect,
                                        cancel: session.cancelReconnect)
            }
        }
    }
}
