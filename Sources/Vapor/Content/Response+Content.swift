extension HTTPResponse {
    // TODO: Weird but solves problem, keep?
    public typealias ContentDidLoad = (request: HTTPResponse, data: Content) -> Void

    // extensible content loading
    private static var contentDidLoad: ContentDidLoad = { _ in }

    public static func register(_ newLoader: ContentDidLoad) {
        let currentLoader = contentDidLoad
        contentDidLoad = { request, content in
            // FIFO
            currentLoader(request: request, data: content)
            newLoader(request: request, data: content)
        }
    }

    public var data: Content {
        if let data = storage["data"] as? Content {
            return data
        } else {
            let data = Content()
            HTTPResponse.contentDidLoad(request: self, data: data)
            data.append { [weak self] in self?.json }
            storage["data"] = data
            return data
        }
    }
}
