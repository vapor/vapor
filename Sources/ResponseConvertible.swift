//
// Based on comment from ElvishJerricco <https://www.reddit.com/r/swift/comments/42n46u/a_laravellumen_inspired_web_framework_for_swift/czc3nw8>
//

public protocol ResponseConvertible {
	func response() -> Response
}

extension String: ResponseConvertible {
	public func response() -> Response {
		return Response(status: .OK, html: self)
	}
}

extension Dictionary: ResponseConvertible {
	public func response() -> Response {
		do {
            return try Response(status: .OK, json: self)    
        } catch {
            return Response(error: "JSON serialization error: \(error)")
        }
	}
}

extension Array: ResponseConvertible {
	public func response() -> Response {
		do {
            return try Response(status: .OK, json: (self as! AnyObject))    
        } catch {
            return Response(error: "JSON serialization error: \(error)")
        }
	}
}