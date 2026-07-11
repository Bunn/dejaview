import Darwin
import Foundation
import OSLog

actor WakeOnLANService: WakeOnLANSending {
    private let destinationPorts: [UInt16]
    private let burstCount: Int

    init(destinationPorts: [UInt16] = [9, 7], burstCount: Int = 3) {
        self.destinationPorts = destinationPorts
        self.burstCount = burstCount
    }

    func sendMagicPacket(to macAddress: MACAddress) async throws {
        let socketDescriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketDescriptor >= 0 else {
            AppLog.wakeOnLAN.error("Failed to create Wake-on-LAN socket; errno=\(errno, privacy: .public)")
            throw WakeOnLANError.couldNotCreateSocket
        }

        defer {
            Darwin.close(socketDescriptor)
        }

        var broadcastEnabled: Int32 = 1
        let optionResult = setsockopt(socketDescriptor,
                                      SOL_SOCKET,
                                      SO_BROADCAST,
                                      &broadcastEnabled,
                                      socklen_t(MemoryLayout<Int32>.size))
        guard optionResult == 0 else {
            AppLog.wakeOnLAN.error("Failed to enable Wake-on-LAN socket broadcast; errno=\(errno, privacy: .public)")
            throw WakeOnLANError.couldNotEnableBroadcast
        }

        let packet = macAddress.magicPacket
        var successfulSendCount = 0
        var lastErrorNumber: Int32 = 0

        for burstIndex in 0..<burstCount {
            for port in destinationPorts {
                if let errorNumber = send(packet, to: port, using: socketDescriptor) {
                    lastErrorNumber = errorNumber
                } else {
                    successfulSendCount += 1
                }
            }

            if burstIndex < burstCount - 1 {
                try await Task.sleep(for: .milliseconds(100))
            }
        }

        guard successfulSendCount > 0 else {
            AppLog.wakeOnLAN.error("Failed to send all Wake-on-LAN packets; errno=\(lastErrorNumber, privacy: .public)")
            throw WakeOnLANError.couldNotSendPacket
        }

        AppLog.wakeOnLAN.info("Sent Wake-on-LAN packet bursts; successfulDatagrams=\(successfulSendCount, privacy: .public)")
    }

    private func send(_ packet: Data,
                      to port: UInt16,
                      using socketDescriptor: Int32) -> Int32? {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("255.255.255.255"))

        let sentByteCount = packet.withUnsafeBytes { packetBuffer in
            withUnsafePointer(to: &address) { addressPointer in
                addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                    Darwin.sendto(socketDescriptor,
                                  packetBuffer.baseAddress,
                                  packetBuffer.count,
                                  0,
                                  socketAddress,
                                  socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        return sentByteCount == packet.count ? nil : errno
    }
}
