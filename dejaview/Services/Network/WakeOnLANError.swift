import Foundation

enum WakeOnLANError: LocalizedError {
    case couldNotCreateSocket
    case couldNotEnableBroadcast
    case couldNotSendPacket

    var errorDescription: String? {
        switch self {
        case .couldNotCreateSocket:
            "The network connection for Wake-on-LAN could not be created."
        case .couldNotEnableBroadcast:
            "This network did not allow a Wake-on-LAN broadcast."
        case .couldNotSendPacket:
            "The Wake-on-LAN packet could not be sent on this network."
        }
    }
}
