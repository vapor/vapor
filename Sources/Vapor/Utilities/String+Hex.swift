extension String {
    init?(hex: Data) {
        guard hex.bytes.count > 0 else { return nil }

        let hexChars = Array("0123456789abcdef".utf8) as [UInt8]
        let bufer = UnsafeBufferPointer<UInt8>(start: UnsafePointer(hex.bytes), count: hex.bytes.count)
        var output = [UInt8](repeating: 0, count: (hex.bytes.count * 2) + 1)
        var ix: Int = 0
        bufer.forEach {
            let hi  = Int(($0 & 0xf0) >> 4)
            let low = Int($0 & 0x0f)
            output[ix] = hexChars[hi]
            ix += 1
            output[ix] = hexChars[low]
            ix += 1
        }
        guard let result = String(validatingUTF8: UnsafePointer(output)) else { return nil }
        self = result
    }
}
