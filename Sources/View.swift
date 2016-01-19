public class View {

	public let resourceDir = "Resources"
	let bytes: [UInt8]

	public init(path: String) {
        let filesPath = View.resourceDir + "/" + path
        
        guard let fileBody = NSData(contentsOfFile: filesPath) else {
            return HttpResponse.NotFound
        }
      
		//TODO: Implement range
        var array = [UInt8](count: fileBody.length, repeatedValue: 0)
        fileBody.getBytes(&array, length: fileBody.length)
        self.bytes = array
	}

	public func render() {
        return HttpResponse.RAW(200, "OK", nil, { $0.write(self.bytes) })
	}

}