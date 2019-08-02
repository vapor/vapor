extension DataProtocol {
    func copyBytes() -> [UInt8] {
        var buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: self.count)
        self.copyBytes(to: buffer)
        defer { buffer.deallocate() }
        return .init(buffer)
    }
}
