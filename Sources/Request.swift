//
// Based on HttpRequest from Swifter (https://github.com/glock45/swifter) by Damian Kołakowski.
//

import Foundation

/**
    Requests contains data sent from a client to the
    web server such as method, parameters, and data.
*/
public class Request {
    
    ///Available HTTP Methods
    public enum Method: String {
        case Get = "GET"
        case Post = "POST"
        case Put = "PUT"
        case Patch = "PATCH"
        case Delete = "DELETE"
        case Unknown = "x"
    }

    ///HTTP Method used for request
    public let method: Method
    ///URL parameters (ex: `:id`)
    public var parameters: [String: String] = [:]
    ///GET or POST data
    public var data: [String: String] = [:]

    public var cookies: [String: String] = [:]
    
    public var path: String = ""
    var headers: [String: String] = [:]
    var body: [UInt8] = []
    var address: String? = ""
    public var session: Session = Session()

    init(method: Method) {
        self.method = method
    }
    
    func parseUrlencodedForm() -> [(String, String)] {
        guard let contentTypeHeader = headers["content-type"] else {
            return []
        }
        let contentTypeHeaderTokens = contentTypeHeader.split(";").map { $0.trim() }
        guard let contentType = contentTypeHeaderTokens.first where contentType == "application/x-www-form-urlencoded" else {
            return []
        }
        return String.fromUInt8(body).split("&").map { (param: String) -> (String, String) in
            let tokens = param.split("=")
            if let name = tokens.first, value = tokens.last where tokens.count == 2 {
                return (name.replace("+", new: " ").removePercentEncoding(),
                        value.replace("+", new: " ").removePercentEncoding())
            }
            return ("","")
        }
    }
    
    struct MultiPart {
        
        let headers: [String: String]
        let body: [UInt8]
        
        var name: String? {
            return valueFor("content-disposition", parameterName: "name")?.unquote()
        }
        
        var fileName: String? {
            return valueFor("content-disposition", parameterName: "filename")?.unquote()
        }
        
        private func valueFor(headerName: String, parameterName: String) -> String? {
            return headers.reduce([String]()) { (currentResults: [String], header: (key: String, value: String)) -> [String] in
                guard header.key == headerName else {
                    return currentResults
                }
                let headerValueParams = header.value.split(";").map { $0.trim() }
                return headerValueParams.reduce(currentResults, combine: { (results:[String], token: String) -> [String] in
                    let parameterTokens = token.split(1, separator: "=")
                    if parameterTokens.first == parameterName, let value = parameterTokens.last {
                        return results + [value]
                    }
                    return results
                })
            }.first
        }
    }
    
    func parseMultiPartFormData() -> [MultiPart] {
        guard let contentTypeHeader = headers["content-type"] else {
            return []
        }
        let contentTypeHeaderTokens = contentTypeHeader.split(";").map { $0.trim() }
        guard let contentType = contentTypeHeaderTokens.first where contentType == "multipart/form-data" else {
            return []
        }
        var boundary: String? = nil
        contentTypeHeaderTokens.forEach({
            let tokens = $0.split("=")
            if let key = tokens.first where key == "boundary" && tokens.count == 2 {
                boundary = tokens.last
            }
        })
        if let boundary = boundary where boundary.utf8.count > 0 {
            return parseMultiPartFormData(body, boundary: "--\(boundary)")
        }
        return []
    }
    
    private func parseMultiPartFormData(data: [UInt8], boundary: String) -> [MultiPart] {
        var generator = data.generate()
        var result = [MultiPart]()
        while let part = nextMultiPart(&generator, boundary: boundary, isFirst: result.isEmpty) {
            result.append(part)
        }
        return result
    }
    
    private func nextMultiPart(inout generator: IndexingGenerator<[UInt8]>, boundary: String, isFirst: Bool) -> MultiPart? {
        if isFirst {
            guard nextMultiPartLine(&generator) == boundary else {
                return nil
            }
        } else {
            nextMultiPartLine(&generator)
        }
        var headers = [String: String]()
        while let line = nextMultiPartLine(&generator) where !line.isEmpty {
            let tokens = line.split(":")
            if let name = tokens.first, value = tokens.last where tokens.count == 2 {
                headers[name.lowercaseString] = value.trim()
            }
        }
        guard let body = nextMultiPartBody(&generator, boundary: boundary) else {
            return nil
        }
        return MultiPart(headers: headers, body: body)
    }
    
    private func nextMultiPartLine(inout generator: IndexingGenerator<[UInt8]>) -> String? {
        var result = String()
        while let value = generator.next() {
            if value > Request.CR {
                result.append(Character(UnicodeScalar(value)))
            }
            if value == Request.NL {
                break
            }
        }
        return result
    }
    
    static let CR = UInt8(13)
    static let NL = UInt8(10)
    
    private func nextMultiPartBody(inout generator: IndexingGenerator<[UInt8]>, boundary: String) -> [UInt8]? {
        var body = [UInt8]()
        let boundaryArray = [UInt8](boundary.utf8)
        var matchOffset = 0;
        while let x = generator.next() {
            matchOffset = ( x == boundaryArray[matchOffset] ? matchOffset + 1 : 0 )
            body.append(x)
            if matchOffset == boundaryArray.count {
                body.removeRange(Range<Int>(start: body.count-matchOffset, end: body.count))
                if body.last == Request.NL {
                    body.removeLast()
                    if body.last == Request.CR {
                        body.removeLast()
                    }
                }
                return body
            }
        }
        return nil
    }
}
