import SwiftUI

struct ExternalDisplayControllerToggle: View {
    let session: VNCSession
    let sessionTitle: String
    @Bindable var coordinator: ExternalDisplayCoordinator

    var body: some View {
        if coordinator.isExternalDisplayAvailable {
            Toggle("Use as Controller",
                   systemImage: "rectangle.inset.filled.and.person.filled",
                   isOn: controllerModeBinding)
        } else {
            Text("Connect an external display first.")
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
