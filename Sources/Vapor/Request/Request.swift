import S4
import MediaType

extension Request {
    ///URL parameters (ex: `:id`).
    public var parameters: [String: String] {
        get {
            guard let parameters = storage["parameters"] as? [String: String] else {
                return [:]
            }

            return parameters
        }
        set(parameters) {
            storage["parameters"] = parameters
        }
    }

    ///Server stored information related from session cookie.
    public var session: Session? {
        get {
            return storage["session"] as? Session
        }
        set(session) {
            storage["session"] = session
        }
    }

    ///Browser stored data sent with every server request
    public var cookies: [String: String] {
        var cookies: [String: String] = [:]

        for cookieString in headers["Cookie"] {
            for (key, val) in parseCookies(cookieString) {
                cookies[key] = val
            }
        }

        return cookies

    }

    public init(method: Method = .get, path: String, host: String? = nil, body: Data = []) {
        self.init(method: method, uri: URI(path: path, host: host), headers: [:], body: body)
    }

    /**
        Cookies are sent to the server as `key=value` pairs
        separated by semicolons.

        - returns: String dictionary of parsed cookies.
     */
    private func parseCookies(_ string: String) -> [String: String] {
        var cookies: [String: String] = [:]

        let cookieTokens = string.split(byString: ";")
        for cookie in cookieTokens {
            let cookieArray = cookie.split(byString: "=")

            if cookieArray.count == 2 {
                let split = cookieArray[0].split(byString: " ")
                let key = split.joined(separator: "")
                let validKey = String(validatingUTF8: key) ?? ""
                cookies[validKey] = String(validatingUTF8: cookieArray[1])
            }
        }

        return cookies
    }
    
    private func parseMultipartForm(_ body: Data, boundary: String) -> [String: MultiPart] {
        let boundaryString = "--" + boundary
        let boundary = Data(boundaryString.utf8)

        let clrf = Data("\r\n".utf8)
        var form = [String: MultiPart]()
        
        // Separate by boundry and loop over the "multi"-parts
        for part in body.split(separator: boundary, excludingFirst: true, excludingLast: true) {
            let headBody = part.split(separator: clrf+clrf)
            var storage = [String: String]()

            // Separate the head and body
            guard headBody.count == 2, let head = headBody.first, let body = headBody.last else {
                continue
            }

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
                    let new = (name: storage["filename"], type: mediaType, data: body)
                    
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
                        form[name] = .file(name: new.name, type: new.type, data: new.data)
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
                    form[name] = .file(name: storage["filename"], type: mediaType, data: body)
                    
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

    private func parseURLEncodedForm(_ string: String) -> [String: MultiPart] {
        var formEncoded: [String: MultiPart] = [:]

        for pair in string.split(byString: "&") {
            let token = pair.split(separator: "=", maxSplits: 1)
            if token.count == 2 {
                let key = String(validatingUTF8: token[0]) ?? ""
                var value = String(validatingUTF8: token[1]) ?? ""
                value = (try? String(percentEncoded: value)) ?? ""
                formEncoded[key] = .input(value)
            }
        }
        
        return formEncoded
    }

    mutating func parseData() {
        data = parseContent()
    }

    private func parseContent() -> Request.Content {
        var queries: [String: String] = [:]
        uri.query.forEach { (key, queryField) in
            queries[key] = queryField
                .values
                .flatMap { $0 }
                .joined(separator: ",")
        }

        var json: Json?
        var formEncoded: [String: MultiPart]?
        var mutableBody = body

        if headers["Content-Type"].first == "application/json" {
            do {
                let data = try mutableBody.becomeBuffer()
                json = try Json(data)
            } catch {
                Log.warning("Could not parse JSON: \(error)")
            }
        } else if headers["Content-Type"].first?.range(of: "multipart/form-data") != nil {
            guard let boundaryPieces = headers["Content-Type"].first?.split(byString: "boundary=") where boundaryPieces.count == 2 else {
                Log.warning("Invalid boundary")
                return Request.Content(query: queries, json: json, formEncoded: formEncoded)
            }
            
            let boundary = boundaryPieces[1]
            
            do {
                let data = try mutableBody.becomeBuffer()
                formEncoded = self.parseMultipartForm(data, boundary: boundary)
            } catch {
                Log.warning("Could not parse multipart form: \(error)")
            }
        } else {
            do {
                let data = try mutableBody.becomeBuffer()
                let string = try String(data: data)
                formEncoded = parseURLEncodedForm(string)
            } catch {
                Log.warning("Could not parse form encoded data: \(error)")
            }
        }

        return Request.Content(query: queries, json: json, formEncoded: formEncoded)
    }

    ///Query data from the path, or POST data from the body (depends on `Method`).
    public var data: Request.Content {
        get {
            guard let data = storage["data"] as? Request.Content else {
                Log.warning("Data has not been parsed.")
                return Request.Content(query: [:], json: nil, formEncoded: nil)
            }

            return data
        }
        set(data) {
            storage["data"] = data
        }
    }

    public struct Handler: Responder {
        public typealias Closure = Request throws -> Response

        let closure: Closure

        /**
         Respond to a given request or throw if fails

         - parameter request: request to respond to

         - throws: an error if response fails

         - returns: a response if possible
         */
        public func respond(to request: Request) throws -> Response {
            return try closure(request)
        }
    }
}

extension Data {
    func split(separator: Data, excludingFirst: Bool = false, excludingLast: Bool = false) -> [Data] {
        var ranges = [(from: Int, to: Int)]()
        var parts = [Data]()

        // "\r\n\r\n\r\n".split(separator: "\r\n\r\n") would break without this because it occurs twice in the same place
        var highestOccurence = -1
        
        // Find occurences of boundries
        for (index, element) in self.enumerated() where index > highestOccurence {
            // If this first element matches and there are enough bytes left
            guard element == separator.first && self.count >= index + separator.count else {
                continue
            }
            
            // Take the last byte of where the end of the separator would be and check it
            guard self[index + separator.count - 1] == separator.bytes.last else {
                continue
            }

            // Check if this range matches (put separately for efficiency)
            guard Data(self[index..<(index+separator.count)]) == separator else {
                continue
            }
            
            // Append the range of the separator
            ranges.append((index, index + separator.count))

            // Increase the highest occurrence to prevent a crash as described above
            highestOccurence = index + separator.count
        }
        
        // The first data (before the first separator)
        if let firstRange = ranges.first where !excludingFirst {
            parts.append(Data(self[0..<firstRange.from]))
        }
        
        // Loop over the ranges
        for (pos, range) in ranges.enumerated() {
            // If this is before the last separator
            if pos < ranges.count - 1 {
                // Take the data inbetween this and the next boundry
                let nextRange = ranges[pos + 1]
                
                parts.append(Data(self[range.to..<nextRange.from]))

            // If this is after the last separator and shouldn't be thrown away
            } else if ranges[ranges.count - 1].to < self.count && !excludingLast {
                parts.append(Data(self[range.to..<self.count]))
            }
        }
        
        return parts
    }
}