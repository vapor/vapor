import Core

extension Multipart {
    public enum Error: Swift.Error {
        case invalidBoundary
    }

    static func parseBoundary(contentType: String) throws -> String {
        let boundaryPieces = contentType.components(separatedBy: "boundary=")
        guard boundaryPieces.count == 2 else {
            throw Error.invalidBoundary
        }
        return boundaryPieces[1]
    }

    static func parse(_ body: Bytes, boundary: String) -> [String: Multipart] {
        let boundary: Bytes = [.hyphen, .hyphen] + boundary.bytes

        var form = [String: Multipart]()
        
        // Separate by boundry and loop over the "multi"-parts
        for part in body.split(separator: boundary, excludingFirst: true, excludingLast: true) {

            let headBody = part.split(separator: Byte.crlf + Byte.crlf)

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
                    var mediaType: String? = nil

                    // Take the content-type if it's there
                    if let contentType = storage["content-type"] {
                        mediaType = contentType
                    }

                    // Create the suple to be added to the array
                    let new = Multipart.File(name: storage["filename"], type: mediaType, data: body)

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
                        let file = Multipart.File(name: new.name, type: new.type, data: new.data)
                        form[name] = .file(file)
                    }
                } else {
                    let new = body.string.components(separatedBy: "\r\n").joined(separator: "")

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
                    var mediaType: String? = nil

                    // Take the optional content type and convert it to a MediaType
                    if let contentType = storage["content-type"] {
                        mediaType = contentType
                    }

                    // Store the file in the form
                    let file = Multipart.File(name: storage["filename"], type: mediaType, data: body)
                    form[name] = .file(file)

                    // If it's not a file (or not for sure) we're storing the information String
                } else {
                    let input = body.string.components(separatedBy: "\r\n").joined(separator: "")
                    form[name] = .input(input)
                }
            }
        }
        return form
    }

    static func parseMultipartStorage(head: Bytes, body: Bytes) -> [String: String]? {
        var storage = [String: String]()

        // Separate the individual headers
        let headers = head.split(separator: Byte.crlf)

        for line in headers {
            // Make the header a String
            let header = line.string.components(separatedBy: "\r\n").joined(separator: "")

            // Split the header parts into an array
            var headerParts = header.characters.split(separator: ";").map(String.init)

            // The header has a base. Like "Content-Type: text/html; other=3" would have "Content-Type: text/html;
            guard let base = headerParts.first else {
                continue
            }

            // The base always has two parts. Key + Value
            let baseParts = base.characters.split(separator: ":", maxSplits: 1).map(String.init)

            // Check that the count is right
            guard baseParts.count == 2 else {
                continue
            }

            // Add the header to the storage
            storage[baseParts[0].bytes.trimmed([.space]).lowercased.string] = baseParts[1].bytes.trimmed([.space]).string

            // Remove the header base so we can parse the rest
            headerParts.remove(at: 0)

            // remaining parts
            for part in headerParts {
                // Split key-value
                let subParts = part.characters.split(separator: "=", maxSplits: 1).map(String.init)

                // There's a key AND a Value. No more, no less
                guard subParts.count == 2 else {
                    continue
                }

                // Strip all unnecessary characters
                storage[subParts[0].bytes.trimmed([.space]).string] = subParts[1].bytes.trimmed([.space, .horizontalTab, .carriageReturn, .newLine, .backSlash, .apostrophe, .quote]).string
            }
        }

        return storage
    }
}
