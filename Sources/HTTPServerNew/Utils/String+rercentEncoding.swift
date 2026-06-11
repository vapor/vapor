extension StringProtocol {
    fileprivate static func hexToAscii(_ hex: UInt8) -> UInt8 {
        switch hex {
        case 0x0:
            return UInt8(ascii: "0")
        case 0x1:
            return UInt8(ascii: "1")
        case 0x2:
            return UInt8(ascii: "2")
        case 0x3:
            return UInt8(ascii: "3")
        case 0x4:
            return UInt8(ascii: "4")
        case 0x5:
            return UInt8(ascii: "5")
        case 0x6:
            return UInt8(ascii: "6")
        case 0x7:
            return UInt8(ascii: "7")
        case 0x8:
            return UInt8(ascii: "8")
        case 0x9:
            return UInt8(ascii: "9")
        case 0xA:
            return UInt8(ascii: "A")
        case 0xB:
            return UInt8(ascii: "B")
        case 0xC:
            return UInt8(ascii: "C")
        case 0xD:
            return UInt8(ascii: "D")
        case 0xE:
            return UInt8(ascii: "E")
        case 0xF:
            return UInt8(ascii: "F")
        default:
            fatalError("Invalid hex digit: \(hex)")
        }
    }

    fileprivate static func asciiToHex(_ ascii: UInt8) -> UInt8? {
        switch ascii {
        case UInt8(ascii: "0"):
            return 0x0
        case UInt8(ascii: "1"):
            return 0x1
        case UInt8(ascii: "2"):
            return 0x2
        case UInt8(ascii: "3"):
            return 0x3
        case UInt8(ascii: "4"):
            return 0x4
        case UInt8(ascii: "5"):
            return 0x5
        case UInt8(ascii: "6"):
            return 0x6
        case UInt8(ascii: "7"):
            return 0x7
        case UInt8(ascii: "8"):
            return 0x8
        case UInt8(ascii: "9"):
            return 0x9
        case UInt8(ascii: "A"), UInt8(ascii: "a"):
            return 0xA
        case UInt8(ascii: "B"), UInt8(ascii: "b"):
            return 0xB
        case UInt8(ascii: "C"), UInt8(ascii: "c"):
            return 0xC
        case UInt8(ascii: "D"), UInt8(ascii: "d"):
            return 0xD
        case UInt8(ascii: "E"), UInt8(ascii: "e"):
            return 0xE
        case UInt8(ascii: "F"), UInt8(ascii: "f"):
            return 0xF
        default:
            return nil
        }
    }


    package static func removingURLPercentEncoding(utf8Buffer: some Collection<UInt8>, excluding: Set<UInt8> = []) -> String? {
        let result: String? = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: utf8Buffer.count) { buffer -> String? in
            var i = 0
            var byte: UInt8 = 0
            var hexDigitsRequired = 0
            for v in utf8Buffer {
                if v == UInt8(ascii: "%") {
                    guard hexDigitsRequired == 0 else {
                        return nil
                    }
                    hexDigitsRequired = 2
                } else if hexDigitsRequired > 0 {
                    guard let hex = asciiToHex(v) else {
                        return nil
                    }
                    if hexDigitsRequired == 2 {
                        byte = hex << 4
                    } else if hexDigitsRequired == 1 {
                        byte += hex
                        if excluding.contains(byte) {
                            // Keep the original percent-encoding for this byte
                            i = buffer[i...i + 2].initialize(fromContentsOf: [UInt8(ascii: "%"), hexToAscii(byte >> 4), v])
                        } else {
                            buffer[i] = byte
                            i += 1
                            byte = 0
                        }
                    }
                    hexDigitsRequired -= 1
                } else {
                    buffer[i] = v
                    i += 1
                }
            }
            guard hexDigitsRequired == 0 else {
                return nil
            }
            return String(decoding: buffer[..<i], as: UTF8.self)
        }
        return result
    }
}
