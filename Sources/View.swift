import Foundation

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
        
        guard let fileBody = NSData(contentsOfFile: filesPath) else {
            self.bytes = []
            Log.error("No view found in path: \(filesPath)")
            throw Error.InvalidPath
        }

        //TODO: Implement range
        var array = [UInt8](count: fileBody.length, repeatedValue: 0)
        fileBody.getBytes(&array, length: fileBody.length)

        self.bytes = array

        for (suffix, renderer) in View.renderers {
            if path.hasSuffix(suffix) {
                let template =  String.fromUInt8(self.bytes)
                let rendered = try renderer.render(template: template, context: context)
                self.bytes = [UInt8](rendered.utf8)
            }
        }

    }

}

extension View: ResponseConvertible {
    public func response() -> Response {
        return Response(status: .OK, data: self.bytes, contentType: .Html)
    }
}

