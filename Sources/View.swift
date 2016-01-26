import Foundation

public class View {

	public static let resourceDir = "Resources"
	let bytes: [UInt8]

	public init(path: String) {
        let filesPath = View.resourceDir + "/" + path
        
        guard let fileBody = NSData(contentsOfFile: filesPath) else {
        	self.bytes = []
            return
        }
      
		//TODO: Implement range
        var array = [UInt8](count: fileBody.length, repeatedValue: 0)
        fileBody.getBytes(&array, length: fileBody.length)
        self.bytes = array
	}

	public func render() -> Response {
        return Response(status: .OK, data: self.bytes, contentType: .Html)
	}

}