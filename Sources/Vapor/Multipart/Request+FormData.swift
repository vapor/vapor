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
            
            guard let type = headers["Content-Type"], type.contains("multipart/form-data") else {
                return nil
            }
            
            guard case let .data(bytes) = self.body else {
                return nil
            }
            
            guard let boundary = try? Multipart.parseBoundary(contentType: type) else {
                return nil
            }
            
            guard let multipart = try? Parser(boundary: boundary) else {
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
                    let r = Int.random(
                        min: Int(Byte.A),
                        max: Int(Byte.z)
                    )
                    random += Byte(r)
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
                    headers.removeValue(forKey: "Content-Type")
                }
            }
        }
    }
}

import Polymorphic

extension FormData.Field: Polymorphic {
    public var isNull: Bool {
        return part.body.string.isNull
    }
    
    public var bool: Bool? {
        return part.body.string.bool
    }
    
    public var double: Double? {
        return part.body.string.double
    }
    
    public var int: Int? {
        return part.body.string.int
    }
    
    public var string: String? {
        return part.body.string
    }
    
    public var array: [Polymorphic]? {
        return part.body.string.array
    }
    
    public var object: [String : Polymorphic]? {
        return part.body.string.object
    }
    
    public var float: Float? {
        return part.body.string.float
    }
    
    public var uint: UInt? {
        return part.body.string.uint
    }
}
