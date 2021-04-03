public protocol RouterFactory {
    func buildRouter<Output>(forOutputType type: Output.Type) -> AnyRouter<Output>
}
