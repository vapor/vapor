import HTTP
import Multipart

private let multipartKey = "vapor:multipart"

extension HTTP.Message {
    /// Multipart encoded request data sent using
    /// the `multipart/mixed...` header.
    public var multipart: [Part]? {
        get {
            if let existing = storage[multipartKey] as? [Part] {
                return existing
            }
            
            guard
                let type = headers[.contentType], type.contains("multipart/mixed"),
                case let .data(bytes) = self.body,
                let boundary = try? Parser.extractBoundary(contentType: type)
            else {
                return nil
            }
            
            let parser = Parser(boundary: boundary)
            
            var parts: [Part] = []
            
            parser.onPart = { part in
                parts.append(part)
            }
            
            do {
                try parser.parse(bytes)
                try parser.finish()
            } catch {
                return nil
            }
            
            storage[multipartKey] = parts
            
            return parts
        }
        set {
            storage[multipartKey] = newValue
            
            if let parts = newValue {
                var serialized: Bytes = []
                
                var random: Bytes = []
                
                // generate safe boundary letters
                // in between A-z in the ascii table
                for _ in 0 ..< 10 {
                    random += Byte.random(min: .A, max: .z)
                }
                
                let boundary: Bytes = "vaporboundary".makeBytes() + random
                
                let serializer = Serializer(boundary: boundary)
                
                serializer.onSerialize = { bytes in
                    serialized += bytes
                }
                
                for part in parts {
                    try? serializer.serialize(part)
                }
                
                try? serializer.finish()
                
                body = .data(serialized)
                headers[.contentType] = "multipart/mixed; boundary=" + boundary.makeString()
            } else {
                if
                    let contentType = headers[.contentType],
                    contentType.contains("multipart/mixed")
                {
                    body = .data([])
                    headers.removeValue(forKey: .contentType)
                }
            }
        }
    }
}
