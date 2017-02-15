import Foundation
import HTTP
import URI

/**
 LoginRedirectMiddleware

 Middleware object used to automatically redirect users to a specific web page if they are not authenticated

 Generally used to redirect to the site's login page. Optionally can redirect the user back to the page they were trying to access before they logged in.
 */
public class LoginRedirectMiddleware: Middleware {
    public let loginPath: String
    public let redirectOrigin: Bool
    public let defaultRedirectPath: String
    public let ignoredOriginPaths: [String]

    /**
     Designated LoginRedirectMiddleware initializer

     - Parameter loginPath: The absolute URI path to where users will be redirected if they are unauthenticated
     - Parameter redirectOrigin: Whether or not to redirect users back to the page they came from before authenticating (default = false)
     - Parameter defaultRedirectPath: The default absolute URI path to return users to after authenticating when the origin value is removed since the route is a part of the ignoredOriginPaths array (default = "/")
     - Parameter ignoredOriginPaths: Paths to avoid redirecting to after the user authenticates, such as the logout page. (default = [])
    */
    public init(loginPath: String, redirectOrigin: Bool = false, defaultRedirectPath: String = "/", ignoredOriginPaths: [String] = []) {
        self.loginPath = loginPath
        self.redirectOrigin = redirectOrigin
        self.defaultRedirectPath = defaultRedirectPath
        self.ignoredOriginPaths = ignoredOriginPaths
    }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        // Make sure we aren't going to the loginPath and are not already authenticated
        guard request.uri.path != loginPath, try !request.subject().authenticated else {
            return try next.respond(to: request)
        }

        // Not authenticated, so build the redirect uri
        var redirect = URI(scheme: request.uri.scheme, host: request.uri.host, port: request.uri.port, path: self.loginPath)

        // If we need to preserve the origin before the redirect, add it to the redirect's query
        if redirectOrigin {
            // Check if the origin request is one of the ignoredOriginPaths and use the default redirect path if it is
            if ignoredOriginPaths.contains(request.uri.path) {
                redirect.addQuery(withKey: "origin", value: defaultRedirectPath)
            } else {
                // Otherwise use the request's full uri as the origin
                redirect.addQuery(withKey: "origin", value: request.uri.description)
            }
        }
        // Redirect to the loginPath
        return Response(redirect: redirect.description)
    }
}

extension Request {
	public var origin: String? {
		return self.uri.getQueryValue(forKey: "origin")
	}
}
