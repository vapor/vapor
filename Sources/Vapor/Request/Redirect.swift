extension Request {
    /// Creates a redirect `Response`.
    ///
    ///     router.get("redirect") { req in
    ///         return req.redirect(to: "https://vapor.codes")
    ///     }
    ///
    /// Set type to '.permanently' to allow caching to automatically redirect from browsers.
    /// Defaulting to non-permanent to prevent unexpected caching.
    public func redirect(to location: String, type: RedirectType = .normal) -> Response {
        let response = Response(byteBufferAllocator: self.byteBufferAllocator)
        response.status = type.status
        response.headers.replaceOrAdd(name: .location, value: location)
        return response
    }
}

/// Specifies the type of redirect that the client should receive.
public enum RedirectType {
    /// A cacheable redirect.
    /// `301 permanent`
    case permanent
    /// Forces the redirect to come with a GET, regardless of req method.
    /// `303 see other`
    case normal
    /// Maintains original request method, ie: PUT will call PUT on redirect.
    /// `307 Temporary`
    case temporary

    /// Associated `HTTPStatus` for this redirect type.
    public var status: HTTPStatus {
        switch self {
        case .permanent: return .movedPermanently
        case .normal: return .seeOther
        case .temporary: return .temporaryRedirect
        }
    }
}
