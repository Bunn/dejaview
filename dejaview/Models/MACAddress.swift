import Foundation

struct MACAddress: Equatable, Sendable {
    let bytes: [UInt8]

    init?(_ value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        let allowedSeparators = CharacterSet(charactersIn: ":-.")
            .union(.whitespacesAndNewlines)
        let hexadecimalDigits = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")

        guard trimmedValue.unicodeScalars.allSatisfy({ scalar in
            hexadecimalDigits.contains(scalar) || allowedSeparators.contains(scalar)
        }) else {
            return nil
        }

        let hexadecimalValue = trimmedValue.filter(\.isHexDigit)
        guard hexadecimalValue.count == 12 else { return nil }

        var parsedBytes: [UInt8] = []
        parsedBytes.reserveCapacity(6)

        var startIndex = hexadecimalValue.startIndex
        for _ in 0..<6 {
            let endIndex = hexadecimalValue.index(startIndex, offsetBy: 2)
            guard let byte = UInt8(hexadecimalValue[startIndex..<endIndex], radix: 16) else {
                return nil
            }

            parsedBytes.append(byte)
            startIndex = endIndex
        }

        guard parsedBytes.contains(where: { $0 != 0 }),
              parsedBytes.contains(where: { $0 != 0xFF }),
              parsedBytes[0] & 1 == 0 else {
            return nil
        }

        bytes = parsedBytes
    }

    var formatted: String {
        bytes.map { byte in
            let component = String(byte, radix: 16, uppercase: true)
            return component.count == 1 ? "0\(component)" : component
        }
        .joined(separator: ":")
    }

    var magicPacket: Data {
        var packet = Data(repeating: 0xFF, count: 6)

        for _ in 0..<16 {
            packet.append(contentsOf: bytes)
        }

        return packet
    }
}
