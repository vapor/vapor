import Multipart
import Foundation

extension MultipartForm: Content {
    public func encode(to encoder: Encoder) throws {
        try MultipartSerializer(form: self).serialize().encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        let data = try Data(from: decoder)
        
        self = try data.withByteBuffer { buffer in
            return try MultipartParser(buffer: buffer, boundary: MultipartParser.boundary(for: data)).parse()
        }
    }
}
