/**
    Swift Servers that conform to this protocol
    can be used to power any Vapor application.
*/
public protocol ServerDriver {
    func boot(ip ip: String, port: Int) throws
    func halt()

    var delegate: ServerDriverDelegate? { get set }
}

/**
    The Application class conforms to `ServerDriverDelegate`
    and will be set as any ServerDriver's delegate when the
    application starts.
*/
public protocol ServerDriverDelegate {
    func serverDriverDidReceiveRequest(request: Request) -> Response
}
