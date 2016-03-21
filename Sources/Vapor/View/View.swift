public class View {

    public static var renderers: [String: RenderDriver] = [:]

	public static let resourceDir = Application.workDir + "Resources"
	var bytes: [UInt8]

    enum Error: ErrorType {
        case InvalidPath
    }

    public convenience init(path: String) throws {
        try self.init(path: path, context: [:])
    }

    public init(path: String, context: [String: Any]) throws {
        let filesPath = View.resourceDir + "/" + path
        
        guard let fileBody = try? FileManager.readBytesFromFile(filesPath) else {
            self.bytes = []
            Log.error("No view found in path: \(filesPath)")
            throw Error.InvalidPath
        }
        self.bytes = fileBody

        for (suffix, renderer) in View.renderers {
            //FIXME
            #if swift(>=3.0)
            if path.hasSuffix(suffix) {
                let template =  String.fromUInt8(self.bytes)
                let rendered = try renderer.render(template: template, context: context)
                self.bytes = [UInt8](rendered.utf8)
            }
            #endif
        }

    }

}

extension View: ResponseConvertible {
    public func response() -> Response {
        return Response(status: .OK, data: self.bytes, contentType: .Html)
    }
}

