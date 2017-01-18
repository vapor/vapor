import HTTP
import FormData
import Multipart
import Random

extension Request {
    /**
        Multipart encoded request data sent using
        the `multipart/form-data...` header.

        Used by web browsers to send files.
    */
    public var formData: [String: Field]? {
        get {
            if let existing = storage["formdata"] as? [String: Field] {
                return existing
            }
            
            guard
                let type = headers[.contentType], type.contains("multipart/form-data"),
                case let .data(bytes) = self.body,
                let boundary = try? Multipart.parseBoundary(contentType: type),
                let multipart = try? Parser(boundary: boundary)
            else {
                return nil
            }
            
            let parser = FormData.Parser(multipart: multipart)
            
            var fields: [String: Field] = [:]
            
            parser.onField = { field in
                fields[field.name] = field
            }
            
            do {
                try parser.multipart.parse(bytes)
                try parser.multipart.finish()
            } catch {
                return nil
            }
            
            return fields
        }
        set {
            storage["formdata"] = newValue
            
            if let fields = newValue {
                var serialized: Bytes = []
                
                var random: Bytes = []
                
                // generate safe boundary letters
                // in between A-z in the ascii table
                for _ in 0 ..< 10 {
                    random += Byte.random(min: .A, max: .z)
                }
                
                let boundary: Bytes = "vaporboundary".bytes + random
                
                let multipart = Serializer(boundary: boundary)
                
                let serializer = FormData.Serializer(multipart: multipart)
                
                serializer.multipart.onSerialize = { bytes in
                    serialized += bytes
                }
                
                for (_, field) in fields {
                    try? serializer.serialize(field)
                }
                
                try? serializer.multipart.finish()
                
                body = .data(serialized)
                headers[.contentType] = "multipart/form-data; boundary=" + boundary.string
            } else {
                if headers[.contentType]?.contains("multipart/form-data") == true {
                    body = .data([])
                    headers.removeValue(forKey: .contentType)
                }
            }
        }
    }
}

extension Byte {
    /// Generate a random byte in the supplied range
    static func random(min: Byte, max: Byte) -> Byte {
        let r = Int.random(
            min: Int(min),
            max: Int(max)
        )
        
        return Byte(r)
    }
}
