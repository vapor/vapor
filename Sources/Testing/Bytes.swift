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
            XCTFail(
                "Failed to convert desired result to bytes: \(error)",
                file: file,
                line: line
            )
            throw TestingError.byteConversionFailed
        }
        return bytes
    }
}
