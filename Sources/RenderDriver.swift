
public protocol RenderDriver {
    func render(template template: String, context: [String: Any]) throws -> String
}