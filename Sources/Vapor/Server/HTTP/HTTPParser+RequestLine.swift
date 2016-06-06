extension HTTPParser {
    struct RequestLine {
        enum Error: ErrorProtocol {
            case invalidRequestLine
        }

        let methodString: String
        let uriString: String
        let versionString: String

        init(_ string: String) throws {
            let comps = string.components(separatedBy: " ")
            guard comps.count == 3 else {
                print(string)
                throw Error.invalidRequestLine
            }

            methodString = comps[0]
            uriString = comps[1]
            versionString = comps[2]
        }

        var version: Request.Version {
            // ["HTTP", "1.1"]
            let parts = versionString.components(separatedBy: "/")

            var major = 0
            var minor = 0

            if parts.count == 2 {
                // ["1", "1"]
                let comps = parts[1].components(separatedBy: ".")

                major = Int(comps[0]) ?? 0

                if comps.count == 2{
                    if let m = Int(comps[1]) {
                        minor = m
                    }
                }
            }

            return Request.Version(major: major, minor: minor)
        }

        var method: Request.Method {
            let method: Request.Method
            switch methodString.lowercased() {
            case "get":
                method = .get
            case "delete":
                method = .delete
            case "head":
                method = .head
            case "post":
                method = .post
            case "put":
                method = .put
            case "connect":
                method = .connect
            case "options":
                method = .options
            case "trace":
                method = .trace
            case "patch":
                method = .patch
            default:
                method = .other(method: methodString)
            }
            return method
        }

        var uri: URI {
            var fields: [String : [String?]] = [:]

            let parts = uriString.split(separator: "?", maxSplits: 1)
            let path = parts.first ?? ""
            let queryString = parts.last ?? ""

            let data = Request.parseFormURLEncoded(queryString.data)

            if case .dictionary(let dict) = data {
                for (key, val) in dict {
                    var array: [String?]

                    if let existing = fields[key] {
                        array = existing
                    } else {
                        array = []
                    }

                    array.append(val.string)

                    fields[key] = array
                }
            }

            return URI(
                scheme: "http",
                userInfo: nil,
                host: nil,
                port: nil,
                path: path,
                query: fields,
                fragment: nil
            )
        }
    }
}
