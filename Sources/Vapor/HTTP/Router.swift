public protocol Router {
    func getRoute(for request: Request) -> Result<Route, Error>
}
