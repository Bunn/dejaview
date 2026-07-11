protocol WakeOnLANSending: Sendable {
    func sendMagicPacket(to macAddress: MACAddress) async throws
}
