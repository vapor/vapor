/// Any entity that is initializable by a Multipart Part
public protocol MultipartInitializable {
    init(part: Part) throws
}

public struct MultipartFile: MultipartInitializable {
    var filename: String?
    var mimeType: String?
    var encoding: TransferEncoding
    
    var data: Data
    
    public init(part: Part) throws {
        self.mimeType = part.headers[.contentType]
        
        TransferEncoding.enc
        self.encoding = part.headers[.contentTransferEncoding]
    }
}
