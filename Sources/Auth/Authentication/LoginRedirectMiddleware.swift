import Foundation
import HTTP
import URI

/**
 LoginRedirectMiddleware

 Middleware object used to automatically redirect users to a specific web page if they are not authenticated

 Generally used to redirect to the site's login page. Optionally can redirect the user back to the page they were trying to access before they logged in.
 */
public class LoginRedirectMiddleware : Middleware {
    public let loginRoute: String
    public let cameFromRedirect: Bool
    public let defaultRedirectRoute: String
    public let ignoredCameFromRoutes: [HTTP.Method : [String]]

    /**
     Designated LoginRedirectMiddleware initializer

     - Parameters:
     - loginRoute: The absolute URI path to where users will be redirected if they are unauthenticated
     - cameFromRedirect: Whether or not to redirect users back to the page they came from before authenticating (default = false)
     - defaultRedirectRoute: The default absolute URI path to return users to after authenticating when the cameFrom value is removed since the route is a part of the ignoredCameFromRoutes array (default = "/")
     - ignoredCameFromRoutes: Routes to avoid redirecting to after the user authenticates, such as the logout page. (default = [])
     */
    public init(loginRoute: String, cameFromRedirect: Bool = false, defaultRedirectRoute: String = "/", ignoredCameFromRoutes: [HTTP.Method : [String]] = [:]) {
        self.loginRoute = loginRoute
        self.cameFromRedirect = cameFromRedirect
        self.defaultRedirectRoute = defaultRedirectRoute
        self.ignoredCameFromRoutes = ignoredCameFromRoutes
    }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        // Make sure we aren't going to the loginRoute
        if (request.uri.path != loginRoute) {
            // Test to see if we're authenticated
            guard try request.subject().authenticated else {
                // Not authenticated, so build the redirect
                let redirect = try Request(method: .get, uri: loginRoute)
                if (cameFromRedirect) {
                    // Add the cameFrom query to the redirect URI
                    redirect.uri.addQuery(withKey: "cameFrom", value: request.uri.description)
                    // Remove the cameFrom query if it happens to be one of the ignored routes
                    for (method, routes) in ignoredCameFromRoutes {
                        for route in routes {
                            if (request.method == method && request.uri.path == route) {
                                redirect.uri.removeQuery(forKey: "cameFrom")
                                break
                            }
                        }
                    }
                    // If we have no cameFrom query, use the defaultRedirectRoute
                    if (redirect.uri.getQueryValue(forKey: "cameFrom") == nil) {
                        redirect.uri.addQuery(withKey: "cameFrom", value: defaultRedirectRoute)
                    }
                }
                // Redirect to the loginRoute
                return Response(redirect: redirect.uri.description)
            }
        }

        // We are authenticated, so continue on to the next middleware
        return try next.respond(to: request)
    }
}

extension Request {
    public func cameFrom() throws -> Request? {
        if let cameFrom = self.uri.getQueryValue(forKey: "cameFrom") {
            self.uri = try URI(cameFrom)
        }
        return self
    }
}

