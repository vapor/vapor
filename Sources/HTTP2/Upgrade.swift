import HTTP

public final class Client {
    public static func shouldUpgrade(request: Request) -> Bool {
        return request.headers[.upgrade] == "h2" || request.headers[.upgrade] == "h2c"
    }
    
    public static func upgradeResponse(for request: Request) throws -> Response {
        guard
            let upgrade = request.headers[.upgrade],
            upgrade == "h2" || upgrade == "h2c"
        else {
            throw Error(.notUpgraded)
        }
        
        if upgrade == "h2" {
            guard request.headers[.http2Settings] != nil else {
                // TODO: Parse base64-ed settings frame
                throw Error(.notUpgraded)
            }
        } else {
            // TODO: ALPN
        }
        
        return Response(status: .upgrade, headers: [
            .connection: "Upgrade",
            .upgrade: upgrade
        ])
    }
}
