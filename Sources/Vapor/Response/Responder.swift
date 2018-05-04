/// Capable of responding to a `Request`.
public protocol Responder {
    /// Asynchronously returns a `Response` for the supplied `Request`.
    ///
    /// - parameters:
    ///     - req: `Request` to respond to.
    /// - returns: A `Future` that contains the returned `Response`.
    func respond(to req: Request) throws -> Future<Response>
}
