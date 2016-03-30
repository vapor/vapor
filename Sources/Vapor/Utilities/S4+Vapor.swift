import S4

extension S4.Method {
    var vaporMethod: Vapor.Request.Method {
        switch self {
        case .get:
            return .Get
        case .post:
            return .Post
        case .put:
            return .Put
        case .patch:
            return .Patch
        case .delete:
            return .Delete
        case .options:
            return .Options
        default:
            return .Unknown
        }
    }
    
}

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
            method: method.vaporMethod,
            path: uri.vaporPath,
            address: nil,
            headers: headers.vaporHeaders,
            body: body.data
        )
    }
}

extension S4.Status {
    var vaporStatus: Vapor.Response.Status {
        return .OK
    }
}

extension S4.Response {
    var vaporResponse: Vapor.Response {
        let response = Vapor.Response(status: status.vaporStatus, data: body.data, contentType: Vapor.Response.ContentType.None)
        
        for header in headers {
            for value in header.value.values {
                response.headers[header.key.string] = value
            }
        }
        
        return response
    }
}

