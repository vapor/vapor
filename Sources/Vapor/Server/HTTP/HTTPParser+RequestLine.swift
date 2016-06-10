import Foundation

extension HTTPParser {
    struct RequestLine {
        static let get = "get".data
        static let delete = "delete".data
        static let head = "head".data
        static let post = "post".data
        static let put = "put".data
        static let connect = "connect".data
        static let options = "options".data
        static let trace = "trace".data
        static let patch = "patch".data
        
        enum Error: ErrorProtocol {
            case invalidRequestLine
        }

        let methodSlice: ArraySlice<Byte>
        let uriSlice: ArraySlice<Byte>
        let versionSlice: ArraySlice<Byte>


        init(_ data: Data) throws {
            let comps = data.split(
                separator: Byte.ASCII.space,
                maxSplits: 3,
                omittingEmptySubsequences: true
            )

            guard comps.count == 3 else {
                throw Error.invalidRequestLine
            }

            methodSlice = comps[0]
            uriSlice = comps[1]
            versionSlice = comps[2]
        }

        var version: Request.Version {
            // ["HTTP", "1.1"]
            let comps = versionSlice.split(separator: Byte.ASCII.slash, maxSplits: 1)

            var major = 0
            var minor = 0

            if comps.count == 2 {
                // ["1", "1"]
                let version = comps[1].split(separator: Byte.ASCII.period, maxSplits: 1)

                major = Data(version[0]).asciiInt ?? 1

                if version.count == 2 {
                    minor = Data(version[1]).asciiInt ?? 1
                }
            }

            return Request.Version(major: major, minor: minor)
        }

        var method: Request.Method {
            let data = Data(methodSlice)

            let method: Request.Method
            switch data.lowercased {
            case RequestLine.get:
                method = .get
            case RequestLine.delete:
                method = .delete
            case RequestLine.head:
                method = .head
            case RequestLine.post:
                method = .post
            case RequestLine.put:
                method = .put
            case RequestLine.connect:
                method = .connect
            case RequestLine.options:
                method = .options
            case RequestLine.trace:
                method = .trace
            case RequestLine.patch:
                method = .patch
            default:
                let string = String(data)
                Log.warning("Did not recognize method, using .other(\(string))")
                method = .other(method: string)
            }
            return method
        }

        var uri: URI {
            let comps = uriSlice.split(separator: Byte.ASCII.questionMark, maxSplits: 1)

            let path: String
            if let pathData = comps.first {
                path = Data(pathData).string
            } else {
                path = "/"
            }

            //TODO: Add Query parsing as middleware

            return URI(
                scheme: "http",
                userInfo: nil,
                host: nil,
                port: nil,
                path: path,
                query: [:],
                fragment: nil
            )
        }
    }
}