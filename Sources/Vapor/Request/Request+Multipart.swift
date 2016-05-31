import MediaType

extension Request {
    public enum MultiPart {
        case files([File])
        case file(File)
        case input(String)
        case inputArray([String])

        public var file: File? {
            if case .file(let file) = self {
                return file
            }

            return nil
        }

        public var files: [File]? {
            if case .files(let files) = self {
                return files
            }

            return nil
        }

        public var input: String? {
            if case .input(let string) = self {
                return string
            }

            return nil
        }

        public var inputArray: [String]? {
            if case .inputArray(let array) = self {
                return array
            }
            
            return nil
        }
    }

    static var clrf: Data {
        return Data("\r\n".utf8)
    }

    static func parseBoundary(contentType: String) throws -> String {
        let boundaryPieces = contentType.components(separatedBy: "boundary=")
        guard boundaryPieces.count == 2 else {
            throw RequestMultiPartError.invalidBoundary
        }
        return boundaryPieces[1]
    }

    static func parseMultipartForm(_ body: Data, boundary: String) -> [String: MultiPart] {
        let boundaryString = "--" + boundary
        let boundary = Data(boundaryString.utf8)

        var form = [String: MultiPart]()
        
        // Separate by boundry and loop over the "multi"-parts
        for part in body.split(separator: boundary, excludingFirst: true, excludingLast: true) {

            let headBody = part.split(separator: clrf+clrf)

            // Separate the head and body
            guard headBody.count == 2, let head = headBody.first, let body = headBody.last else {
                continue
            }

            guard let storage = parseMultipartStorage(head: head, body: body) else {
                continue
            }

            // There's always a name for a field. Otherwise we can't store it under a key
            guard let name = storage["name"] else {
                continue
            }

            // If this key already exists it needs to be an array
            if form.keys.contains(name) {
                // If it's a file.. there are multiple files being uploaded under the same key
                if storage.keys.contains("content-type") || storage.keys.contains("filename") {
                    var mediaType: MediaType? = nil

                    // Take the content-type if it's there
                    if let contentType = storage["content-type"] {
                        mediaType = try? MediaType(string: contentType)
                    }

                    // Create the suple to be added to the array
                    let new = MultiPart.File(name: storage["filename"], type: mediaType, data: body)

                    // If there is only one file. Make it a file array
                    if let o = form[name], case .file(let old) = o {
                        form[name] = .files([old, new])

                        // If there's a file array. Append it
                    } else if let o = form[name], case .files(var old) = o {
                        old.append(new)
                        form[name] = .files(old)

                        // If it's neither.. It's a duplicate key. This means we're going to be ditched or overriding the existing key
                        // Since we're later, we're overriding
                    } else {
                        let file = MultiPart.File(name: new.name, type: new.type, data: new.data)
                        form[name] = .file(file)
                    }
                } else {
                    var new = String(body)
                    new.replace(string: "\r\n", with: "")

                    if let o = form[name], case .input(let old) = o {
                        form[name] = .inputArray([old, new])
                    } else if let o = form[name], case .inputArray(var old) = o {
                        old.append(new)
                        form[name] = .inputArray(old)
                    } else {
                        form[name] = .input(new)
                    }
                }

                // If it's a new key
            } else {
                // Ensure it's a file. There's no proper way of detecting this if there's no filename and no content-type
                if storage.keys.contains("content-type") || storage.keys.contains("filename") {
                    var mediaType: MediaType? = nil

                    // Take the optional content type and convert it to a MediaType
                    if let contentType = storage["content-type"] {
                        mediaType = try? MediaType(string: contentType)
                    }

                    // Store the file in the form
                    let file = MultiPart.File(name: storage["filename"], type: mediaType, data: body)
                    form[name] = .file(file)

                    // If it's not a file (or not for sure) we're storing the information String
                } else {
                    var input = String(body)
                    input.replace(string: "\r\n", with: "")

                    form[name] = .input(input)
                }
            }

        }
    
        return form
    }

    static func parseMultipartStorage(head: Data, body: Data) -> [String: String]? {
        var storage = [String: String]()

        // Separate the individual headers
        let headers = head.split(separator: clrf)

        for line in headers {
            // Make the header a String
            var header = String(line)
            header.replace(string: "\r\n", with: "")

            // Split the header parts into an array
            var headerParts = header.split(separator: ";")

            // The header has a base. Like "Content-Type: text/html; other=3" would have "Content-Type: text/html;
            guard let base = headerParts.first else {
                continue
            }

            // The base always has two parts. Key + Value
            let baseParts = base.split(separator: ":", maxSplits: 1)

            // Check that the count is right
            guard baseParts.count == 2 else {
                continue
            }

            // Add the header to the storage
            storage[baseParts[0].trim().lowercased()] = baseParts[1].trim()

            // Remove the header base so we can parse the rest
            headerParts.remove(at: 0)

            // remaining parts
            for part in headerParts {
                // Split key-value
                let subParts = part.split(separator: "=", maxSplits: 1)

                // There's a key AND a Value. No more, no less
                guard subParts.count == 2 else {
                    continue
                }

                // Strip all unnecessary characters
                storage[subParts[0].trim()] = subParts[1].trim([" ", "\t", "\r", "\n", "\"", "'"])
            }
        }

        return storage
    }
}

public enum RequestMultiPartError: ErrorProtocol {
    case invalidBoundary
}

extension Request.MultiPart {
    public struct File {
        public var name: String?
        public var type: MediaType?
        public var data: Data
    }
}

extension Request.MultiPart: Polymorphic {
    public var isNull: Bool {
        return self.input == "null"
    }

    public var bool: Bool? {
        if case .input(let bool) = self {
            return Bool(bool)
        }

        return nil
    }

   public var int: Int? {
        guard let double = double else { return nil }
        return Int(double)
    }

    public var uint: UInt? {
        guard let double = double else { return nil }
        return UInt(double)
    }

    public var float: Float? {
        guard let double = double else { return nil }
        return Float(double)
    }

    public var double: Double? {
        if case .input(let d) = self {
            return Double(d)
        }

        return nil
    }

    public var string: String? {
        return self.input
    }
    
    public var array: [Polymorphic]? {
        guard case .input(let a) = self else {
            return nil
        }

        return [a]
    } 

    public var object: [String : Polymorphic]? {
        return nil
    }

    public var json: JSON? {
        if case .input(let j) = self {
            return JSON(j)
        }

        return nil
    }
}
