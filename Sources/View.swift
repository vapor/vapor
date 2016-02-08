import Foundation
import Stencil

public class View {

    public static var renderers: [String: RenderDriver] = [
        ".stencil": StencilRenderer()
    ]

	public static let resourceDir = Server.workDir + "Resources"
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

public protocol RenderDriver {
    func render(template template: String, context: [String: Any]) throws -> String
}

public class StencilRenderer: RenderDriver {

    public func render(template template: String, context: [String: Any]) throws -> String {
        let c = Context(dictionary: context)
        let template = Template(templateString: template)
        return try template.render(c)
    }
    
}