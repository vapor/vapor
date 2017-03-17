import HTTP
import FormData
import Multipart

private let formDataKey = "formData"

extension HTTP.Message {
    /**
        Multipart encoded request data sent using
        the `multipart/form-data...` header.

        Used by web browsers to send files.
    */
    public var formData: [String: Field]? {
        get {
            if let existing = storage[formDataKey] as? [String: Field] {
                return existing
            }
            
            guard
                let type = headers[.contentType], type.contains("multipart/form-data"),
                case let .data(bytes) = self.body,
                let boundary = try? Parser.extractBoundary(contentType: type)
                else { return nil }

            let multipart = Parser(boundary: boundary)
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

            storage[formDataKey] = fields
            
            return fields
        }
        set {
            storage[formDataKey] = newValue
            
            if let fields = newValue {
                var serialized: Bytes = []
                
                var random: Bytes = []
                
                // generate safe boundary letters
                // in between A-z in the ascii table
                for _ in 0 ..< 10 {
                    random += Byte.random(min: .A, max: .z)
                }
                
                let boundary: Bytes = "vaporboundary".makeBytes() + random
                
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
                headers[.contentType] = "multipart/form-data; boundary=" + boundary.makeString()
            } else {
                if
                    let contentType = headers[.contentType],
                    contentType.contains("multipart/form-data")
                {
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
