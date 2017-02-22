import HTTP

extension Responder {
    @discardableResult
    public func testResponse(
        to method: HTTP.Method,
        at path: String,
        file: StaticString = #file,
        line: UInt = #line
        ) throws -> Response {
        let req = try Request.makeTest(method: .get, path: "foo")
        return try testResponse(
            to: req,
            file: file,
            line: line
        )
    }

    @discardableResult
    public func testResponse(
        to req: Request,
        file: StaticString = #file,
        line: UInt = #line
        ) throws -> Response {
        let res: Response

        do {
            res = try respond(to: req)
        } catch {
            XCTFail(
                "Failed to create response: \(error)",
                file: file,
                line: line
            )
            throw TestingError.respondFailed
        }

        return res
    }
}
