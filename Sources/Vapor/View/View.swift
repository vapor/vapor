import Engine

/**
    Loads and renders a file from the `Resources` folder
    in the Droplet's work directory.
*/
public class View {
    ///Currently applied RenderDrivers
    public static var renderers: [String: RenderDriver] = [:]

    var data: Bytes

    enum Error: Swift.Error {
        case InvalidPath
    }

    /**
        Attempt to load and render a file
        from the supplied path using the contextual
        information supplied.
        - context Passed to RenderDrivers
    */
    public init(workDir: String, path: String, context: [String: Any] = [:]) throws {
        let filesPath = workDir + "Resources/Views/" + path

        guard let fileBody = try? FileManager.readBytesFromFile(filesPath) else {
            self.data = Bytes()
            throw Error.InvalidPath
        }
        self.data = fileBody

        for (suffix, renderer) in View.renderers {
            if path.hasSuffix(suffix) {
                let template = data.string
                let rendered = try renderer.render(template: template, context: context)
                self.data = rendered.bytes
            }
        }

    }

}

///Allows Views to be returned in Vapor closures
extension View: HTTPResponseRepresentable {
    public func makeResponse(for: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(status: .ok, headers: [
            "Content-Type": "text/html; charset=utf-8"
        ], body: .data(data))
    }
}

///Adds convenience method to Droplet to create a view
extension Droplet {

    /**
        Views directory relative to Droplet.resourcesDir
    */
    public var viewsDir: String {
        return resourcesDir + "Views/"
    }

    /**
     Loads a view with a given context

     - parameter path: the path to the view
     - parameter context: the context to use when loading the view

     - throws: an error if loading fails
     */
    public func view(_ path: String, context: [String: Any] = [:]) throws -> View {
        return try View(workDir: self.workDir, path: path, context: context)
    }

}
