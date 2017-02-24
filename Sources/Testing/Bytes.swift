import Core

extension BytesConvertible {
    func testMakeBytes(
        file: StaticString = #file,
        line: UInt = #line
        ) throws -> Bytes {
        let bytes: Bytes
        do {
            bytes = try makeBytes()
        } catch {
            onFail(
                "Failed to convert desired result to bytes: \(error)",
                file,
                line
            )
            throw TestingError.byteConversionFailed
        }
        return bytes
    }
}
