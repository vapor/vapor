import Vapor

public func boot(_ app: Application) throws {
    // your code here
    try app.client().webSocket("ws://echo.websocket.org").flatMap { ws -> Future<Void> in
        ws.send("hi")
        ws.onText { ws, text in
            print("rec: \(text)")
            ws.close()
        }
        return ws.onClose
    }.wait()
}
