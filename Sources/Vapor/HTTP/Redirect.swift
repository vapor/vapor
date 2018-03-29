extension Request {
    /// Creates a redirect response.
    ///
    ///     return req.redirect(to: "/login")
    ///
    /// Set type to '.permanently' to allow caching to automatically redirect from browsers.
    /// Defaulting to non-permanent to prevent unexpected caching.
    public func redirect(to location: String, type: RedirectType = .normal) -> Response {
        let res = makeResponse()
        res.http.status = type.status
        res.http.headers.replaceOrAdd(name: "Location", value: location)
        return res
    }
}


/// Specifies the type of redirect that the client should receive.
public enum RedirectType {
    /// A cacheable redirect
    case permanent // 301 permanent
    /// Forces the redirect to come with a GET, regardless of req method
    case normal // 303 see other
    /// Maintains original request method, ie: PUT will call PUT on redirect
    case temporary // 307 temporary

    /// The HTTP status for this redirect type
    fileprivate var status: HTTPResponseStatus {
        switch self {
        case .permanent:
            return .movedPermanently
        case .normal:
            return .seeOther
        case .temporary:
            return .temporaryRedirect
        }
    }
}

