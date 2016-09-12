import Core
import HTTP

final class ErrorView {
    let one: Bytes
    let two: Bytes
    let three: Bytes

    init() {
        var path = #file.characters.split(separator: "/").dropLast().map({ String($0) })
        path.append("error.html")

        let file = "/" + path.joined(separator: "/")
        do {
            let string = try DataFile().load(path: file).string

            let comps = string.components(separatedBy: "#(code)")
            one = comps.first?.bytes ?? []

            if let compsTwo = comps.last?.components(separatedBy: "#(message)") {
                two = compsTwo.first?.bytes ?? []
                three = compsTwo.last?.bytes ?? []
            } else {
                two = []
                three = []
            }
        } catch {
            one = "<h1>".bytes
            two = "</h1><p>".bytes
            three = "</p>".bytes
        }
    }

    func render(code: Int, message: String) -> Bytes {
        return one + code.description.bytes + two + message.bytes + three
    }

    func makeResponse(_ status: Status, _ message: String) -> Response {
        let data = render(code: status.statusCode, message: message)
        let response = Response(status: status, body: .data(data))
        response.headers["Content-Type"] = "text/html; charset=utf-8"
        return response
    }

    static var shared: ErrorView {
        return errorView
    }
}

private let errorView = ErrorView()
