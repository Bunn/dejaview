import SwiftUI

struct ExternalDisplayControllerToggle: View {
    let session: VNCSession
    let sessionTitle: String
    @Bindable var coordinator: ExternalDisplayCoordinator

    var body: some View {
        Toggle("Use This Device as Controller",
               systemImage: "rectangle.inset.filled.and.person.filled",
               isOn: controllerModeBinding)
            .disabled(!coordinator.isExternalDisplayAvailable)

        if !coordinator.isExternalDisplayAvailable {
            Text("Connect an external display to make controller mode available.")
        }
    }

    private var controllerModeBinding: Binding<Bool> {
        Binding {
            coordinator.isControllerModeEnabled(for: session)
        } set: { isEnabled in
            coordinator.setControllerModeEnabled(isEnabled,
                                                 for: session,
                                                 title: sessionTitle)
        }
    }
}
