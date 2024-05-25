protocol RenderableError: Error {
    func render(_ req: Request) async -> Response
}
