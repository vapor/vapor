/**
    Responsible for receiving requests
    and sending responses from the application
    to the underlying server technology.
*/
public protocol ServerDriver {
    init(host: String, port: Int, application: Application) throws
    func start() throws
}
