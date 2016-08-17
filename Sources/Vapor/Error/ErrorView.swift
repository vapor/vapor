import HTTP

public final class ErrorView {
    let request: Request
    let code: Int
    let message: String

    public init(request: Request, code: Int, message: String) {
        self.request = request
        self.code = code
        self.message = message
    }
}

extension ErrorView: ResponseRepresentable {
    public func makeResponse() throws -> Response {
        if request.accept.prefers("html") {
            var path = #file.components(separatedBy: "/ErrorView.swift").joined(separator: "")
            path += "/error.html"
            print(path)
            do {
                let fileBody = try FileManager.readBytesFromFile(path)
                let response = Response(status: .ok, headers: [
                    "Content-Type": "text/html"
                ], body: fileBody)
                return response
            } catch {
                return "Whoops".makeResponse()
            }
        } else {
            return try JSON(node: [
                "error": true,
                "message": message
            ]).makeResponse()
        }
    }
}
