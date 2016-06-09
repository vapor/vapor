import Foundation

extension HTTPParser {
    struct RequestLine {
        static private let questionMark = Data([0x3f])
        static private let whitespace = Data([0x20])
        static private let slash = Data([0x2f])
        static private let dot = Data([0x2e])
        
        static private let get = "get".data
        static private let delete = "delete".data
        static private let head = "head".data
        static private let post = "post".data
        static private let put = "put".data
        static private let connect = "connect".data
        static private let options = "options".data
        static private let trace = "trace".data
        static private let patch = "patch".data
        
        enum Error: ErrorProtocol {
            case invalidRequestLine
        }

        let methodBytes: Data
        var methodString: String {
            return String(methodBytes)
        }
        
        let uriBytes: Data
        var uriString: String {
            return String(uriBytes)
        }
        
        let versionBytes: Data
        var versionString: String {
            return String(versionBytes)
        }

        init(_ string: String) throws {
            let comps = Data(string).split(separator: HTTPParser.RequestLine.whitespace, excludingFirst: false, excludingLast: false, maxSplits: 3)
            guard comps.count == 3 else {
                print(string)
                throw Error.invalidRequestLine
            }

            methodBytes = comps[0]
            uriBytes = comps[1]
            versionBytes = comps[2]
        }

        var version: Request.Version {
            // ["HTTP", "1.1"]
            let parts = versionBytes.split(separator: HTTPParser.RequestLine.slash, excludingFirst: false, excludingLast: false, maxSplits: 1)

            var major = 0
            var minor = 0

            if parts.count == 2 {
                // ["1", "1"]
                let comps = parts[1].split(separator: HTTPParser.RequestLine.dot, excludingFirst: false, excludingLast: false, maxSplits: 1)

                major = Int(String(comps[0])) ?? 0

                if comps.count == 2 {
                    if let m = Int(String(comps[1])) {
                        minor = m
                    }
                }
            }

            return Request.Version(major: major, minor: minor)
        }

        var method: Request.Method {
            let method: Request.Method
            switch methodBytes.lowercased() {
            case HTTPParser.RequestLine.get:
                method = .get
            case HTTPParser.RequestLine.delete:
                method = .delete
            case HTTPParser.RequestLine.head:
                method = .head
            case HTTPParser.RequestLine.post:
                method = .post
            case HTTPParser.RequestLine.put:
                method = .put
            case HTTPParser.RequestLine.connect:
                method = .connect
            case HTTPParser.RequestLine.options:
                method = .options
            case HTTPParser.RequestLine.trace:
                method = .trace
            case HTTPParser.RequestLine.patch:
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
            
            
            let data = FormURLEncoded.parse(queryString.data)

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