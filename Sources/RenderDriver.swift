/**
 * Classes conforming to the `RenderDriver` protocol
 * may be set as the `View`'s renderer for given file extensions.
 *
 * When a file with the given extension is loaded into the `View`
 * class, it will be passed through the supplied `RenderDriver` along
 * with any context information given by the user. 
 */
public protocol RenderDriver {
    func render(template template: String, context: [String: Any]) throws -> String
}