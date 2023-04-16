extension Request {
    /// Creates a redirect `Response`.
    ///
    ///     router.get("redirect") { req in
    ///         return req.redirect(to: "https://vapor.codes")
    ///     }
    ///
    /// Set type to '.permanently' to allow caching to automatically redirect from browsers.
    /// Defaulting to non-permanent to prevent unexpected caching.
    /// - Parameters:
    ///   - location: The path to redirect to
    ///   - type: The type of redirect to perform
    /// - Returns: A response that provides a redirect to the specified location
    @available(*, deprecated, renamed: "redirect(to:redirectType:)")
    public func redirect(to location: String, type: RedirectType) -> Response {
        let response = Response()
        response.status = type.status
        response.headers.replaceOrAdd(name: .location, value: location)
        return response
    }
    
    /// Creates a redirect `Response`.
    ///
    ///     router.get("redirect") { req in
    ///         return req.redirect(to: "https://vapor.codes")
    ///     }
    ///
    /// Set type to '.permanently' to allow caching to automatically redirect from browsers.
    /// Defaulting to non-permanent to prevent unexpected caching.
    /// - Parameters:
    ///   - location: The path to redirect to
    ///   - redirectType: The type of redirect to perform
    /// - Returns: A response that redirects the client to the specified location
    public func redirect(to location: String, redirectType: Redirect = .normal) -> Response {
        let response = Response()
        response.status = redirectType.status
        response.headers.replaceOrAdd(name: .location, value: location)
        return response
    }
}

/// Specifies the type of redirect that the client should receive.
@available(*, deprecated, renamed: "Redirect")
public enum RedirectType {
    /// A cacheable redirect. Not all user-agents preserve request method and body, so
    /// this should only be used for GET or HEAD requests
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

/// Specifies the type of redirect that the client should receive.
public struct Redirect: Sendable {
    let kind: Kind
    
    /// A cacheable redirect. Not all user-agents preserve request method and body, so
    /// this should only be used for GET or HEAD requests
    /// `301 permanent`
    public static var permanent: Redirect {
        return Self(kind: .permanent)
    }
    
    /// Forces the redirect to come with a GET, regardless of req method.
    /// `303 see other`
    public static var normal: Redirect {
        return Self(kind: .normal)
    }
    
    /// Maintains original request method, ie: PUT will call PUT on redirect.
    /// `307 Temporary`
    public static var temporary: Redirect {
        return Self(kind: .temporary)
    }
    
    /// Redirect where the request method and the body will not be altered. This should
    /// be used for POST redirects.
    /// `308 Permanent Redirect`
    public static var permanentPost: Redirect {
        return Self(kind: .permanentPost)
    }

    /// Associated `HTTPStatus` for this redirect type.
    public var status: HTTPStatus {
        switch self.kind {
        case .permanent: return .movedPermanently
        case .normal: return .seeOther
        case .temporary: return .temporaryRedirect
        case .permanentPost: return .permanentRedirect
        }
    }
    
    enum Kind: Sendable {
        case permanent
        case normal
        case temporary
        case permanentPost
    }
}
