import class Engine.HTTPResponse

extension HTTPResponse {
    public var data: Content {
        if let data = storage["data"] as? Content {
            return data
        } else {
            let data = Content()
            data.append { [weak self] in self?.json }
            storage["data"] = data
            return data
        }
    }
}
