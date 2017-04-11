import HTTP

extension Responder {
    @discardableResult
    public func testResponse(
        to method: HTTP.Method,
        at path: String,
        hostname: String = "0.0.0.0",
        headers: [HeaderKey: String] = [:],
        body: BodyRepresentable? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Response {
        let req = Request.makeTest(
            method: .get,
            headers: headers,
            body: body?.makeBody() ?? .data([]),
            hostname: hostname,
            path: path
        )
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
            onFail(
                "Failed to create response: \(error)",
                file,
                line
            )
            throw TestingError.respondFailed
        }

        return res
    }
}
