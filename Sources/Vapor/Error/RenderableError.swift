protocol RenderableError: Error {
    func render(_ req: Request) -> Response
}
