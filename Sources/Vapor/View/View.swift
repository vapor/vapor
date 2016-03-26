/**
    Loads and renders a file from the `Resources` folder
    in the Application's work directory.
*/
public class View {
    ///Currently applied RenderDrivers
    public static var renderers: [String: RenderDriver] = [:]

    var bytes: [UInt8]
    
    #if !swift(>=3.0)
        typealias ErrorType = ErrorProtocol
    #endif

    enum Error: ErrorProtocol {
        case InvalidPath
    }

    /**
        Attempt to load and render a file
        from the supplied path using the contextual
        information supplied.
        - context Passed to RenderDrivers
    */
    public init(application: Application, path: String, context: [String: Any] = [:]) throws {
        let filesPath = application.workDir + "Resources/" + path

        guard let fileBody = try? FileManager.readBytesFromFile(filesPath) else {
            self.bytes = []
            Log.error("No view found in path: \(filesPath)")
            throw Error.InvalidPath
        }
        self.bytes = fileBody

        for (suffix, renderer) in View.renderers {
            if path.hasSuffix(suffix) {
                let template =  String.fromUInt8(self.bytes)
                let rendered = try renderer.render(template: template, context: context)
                self.bytes = [UInt8](rendered.utf8)
            }
        }

    }

}

///Allows Views to be returned in Vapor closures
extension View: ResponseConvertible {
    public func response() -> Response {
        return Response(status: .OK, data: self.bytes, contentType: .Html)
    }
}

///Adds convenience method to Application to create a view
extension Application {

    public func view(path: String, context: [String: Any] = [:]) throws -> View {
        return try View(application: self, path: path, context: context)
    }

}
