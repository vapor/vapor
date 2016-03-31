import S4

extension S4.Headers {
    var vaporHeaders: [(String, String)] {
        var vaporHeaders: [(String, String)] = []
        
        headers.forEach { (key, values) in
            for value in values {
                vaporHeaders.append((key.string, value))
            }
        }
        
        return vaporHeaders
    }
}

extension S4.Body {
    var data: Data {
        switch self {
        case .buffer(let data):
            return data
        case .stream(let stream):
            let data = S4.Drain(stream).data
            return data
        }
    }
}

extension URI {
    var vaporPath: String {
        return path ?? ""
    }
}

extension S4.Request {
    var vaporRequest: Vapor.Request {
        return Vapor.Request.init(
            method: method,
            path: uri.vaporPath,
            address: nil,
            headers: headers,
            body: body.data
        )
    }
}

extension S4.Response {
    var vaporResponse: Vapor.Response {
        let response = Vapor.Response(status: status, data: body.data, contentType: Vapor.Response.ContentType.None)
        
        for header in headers {
            for value in header.value.values {
                response.headers[header.key.string] = value
            }
        }
        
        return response
    }
}

