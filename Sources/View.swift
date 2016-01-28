import Foundation

public class View {

	public static let resourceDir = "Resources"
	let bytes: [UInt8]

    enum Error: ErrorType {
        case InvalidPath
    }

    public init(path: String) throws {
        let filesPath = View.resourceDir + "/" + path
        
        guard let fileBody = NSData(contentsOfFile: filesPath) else {
            throw Error.InvalidPath
        }
      
        //TODO: Implement range
        var array = [UInt8](count: fileBody.length, repeatedValue: 0)
        fileBody.getBytes(&array, length: fileBody.length)
        self.bytes = array
    }

}

extension View: ResponseConvertible {
    public func response() -> Response {
        return Response(status: .OK, data: self.bytes, contentType: .Html)
    }
}