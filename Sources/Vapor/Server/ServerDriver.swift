import Foundation

public protocol ServerDriver {
    func boot(ip ip: String, port: Int) throws
    func halt()

    var delegate: ServerDriverDelegate? { get set }
}

public protocol ServerDriverDelegate {
    func serverDriverDidReceiveRequest(request: Request) -> Response
}