import HTTP

public protocol ErrorRenderer {
    func make(with req: Request, for error: Error) -> Response
}
