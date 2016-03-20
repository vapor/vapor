//
// Based on comment from ElvishJerricco <https://www.reddit.com/r/swift/comments/42n46u/a_laravellumen_inspired_web_framework_for_swift/czc3nw8>
//
// Allows Request closures to simply return `String`s, `Dictionary`s, or `Array`s. 
//
// Additionally, Vapor projects may define their own `ResponseConvertible` objects
//

public protocol ResponseConvertible {
	func response() -> Response
}


extension Response: ResponseConvertible {
    public func response() -> Response {
        return self
    }
}

extension Swift.String: ResponseConvertible {
	public func response() -> Response {
		return Response(status: .OK, html: self)
	}
}
