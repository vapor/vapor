import Bits
import Core
import Foundation
import HTTP

/// Internal error view used to create error HTML pages.
internal final class ErrorView {
    let head: Bytes
    let middle: Bytes
    let tail: Bytes

    init() {
        var path = #file.characters.split(separator: "/").dropLast().map({ String($0) })
        path.append("error.html")

        let file = "/" + path.joined(separator: "/")
        let string = FileManager.default.contents(atPath: file)?.makeString() ?? ""

        let comps = string.components(separatedBy: "#(code)")
        head = comps.first?.makeBytes() ?? []

        if let compsTwo = comps.last?.components(separatedBy: "#(message)") {
            middle = compsTwo.first?.makeBytes() ?? []
            tail = compsTwo.last?.makeBytes() ?? []
        } else {
            middle = []
            tail = []
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
