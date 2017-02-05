import Core
import HTTP

public final class ErrorView {
    let head: Bytes
    let middle: Bytes
    let tail: Bytes

    public init() {
        var path = #file.characters.split(separator: "/").dropLast().map({ String($0) })
        path.append("error.html")

        let file = "/" + path.joined(separator: "/")
        do {
            let string = try DataFile().load(path: file).string

            let comps = string.components(separatedBy: "#(code)")
            head = comps.first?.bytes ?? []

            if let compsTwo = comps.last?.components(separatedBy: "#(message)") {
                middle = compsTwo.first?.bytes ?? []
                tail = compsTwo.last?.bytes ?? []
            } else {
                middle = []
                tail = []
            }
        } catch {
            head = "<h1>".bytes
            middle = "</h1><p>".bytes
            tail = "</p>".bytes
        }
    }

    public func render(code: Int, message: String) -> Bytes {
        return head + code.description.bytes + middle + message.bytes + tail
    }

    public func makeResponse(_ status: Status, _ message: String) -> Response {
        let data = render(code: status.statusCode, message: message)
        let response = Response(status: status, body: .data(data))
        response.headers["Content-Type"] = "text/html; charset=utf-8"
        return response
    }

    public static var shared: ErrorView {
        return errorView
    }
}

private let errorView = ErrorView()
