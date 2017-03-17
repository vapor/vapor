import Core
import HTTP

fileprivate final class ErrorView {
    let head: Bytes
    let middle: Bytes
    let tail: Bytes

    init() {
        var path = #file.characters.split(separator: "/").dropLast().map({ String($0) })
        path.append("error.html")

        let file = "/" + path.joined(separator: "/")
        do {
            let string = try DataFile().load(path: file).makeString()

            let comps = string.components(separatedBy: "#(code)")
            head = comps.first?.makeBytes() ?? []

            if let compsTwo = comps.last?.components(separatedBy: "#(message)") {
                middle = compsTwo.first?.bytes ?? []
                tail = compsTwo.last?.bytes ?? []
            } else {
                middle = []
                tail = []
            }
        } catch {
            head = "<h1>".makeBytes()
            middle = "</h1><p>".makeBytes()
            tail = "</p>".makeBytes()
        }
    }

    func render(code: Int, message: String) -> Bytes {
        return head + code.description.makeBytes() + middle + message.makeBytes() + tail
    }

    func makeResponse(_ status: Status, _ message: String) -> Response {
        let data = render(code: status.statusCode, message: message)
        let response = Response(status: status, body: .data(data))
        response.headers["Content-Type"] = "text/html; charset=utf-8"
        return response
    }
}

fileprivate let errorView = ErrorView()

public extension ViewRenderer {
    public func make(_ error: Error) -> View {
        let status: Status = Status(error)
        let bytes = errorView.render(
            code: status.statusCode,
            message: status.reasonPhrase
        )
        return View(bytes: bytes)
    }
}
