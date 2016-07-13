extension Signature {
    var documentation: String {
        var d = ""

        d << "/**"

        if variant == .socket {
            d << "   Establishes a WebSocket connection"
            d << "   at the given path. WebSocket connections"
            d << "   can be accessed using the `ws://` or `wss://`"
            d << "   schemes to provide two way information"
            d << "   transfer between the client and the server."
            d << ""
            d << "   **Body**"
            d << "   The body closure is given access to the Request"
            d << "   that started the connection as well as the WebSocket."
            d << ""
            d << "       drop.socket(\"test\") { request, ws in"
            d << ""
            d << "   }"
            d << ""
            d << "   **Sending Data**"
            d << ""
            d << "   Data is sent to the WebSocket stream using `send(_:Data)`"
            d << ""
            d << "       try ws.send(\"Hello, world\")"
            d << ""
            d << "   **Receiving Data**"
            d << ""
            d << "   Data is received from the WebSocket using"
            d << "   the `onText` callback."
            d << ""
            d << "   ws.onText = { ws, text in"
            d << "       drop.console.output(\"Received \\(text)\")"
            d << "   }"
            d << ""
            d << "   **Closing**"
            d << ""
            d << "   Close the Socket when you are done."

            d << "       try ws.close()"
            d << ""
            d << "   **Routing**"
            d << ""
        }


        d << "    This route will run for any \(method.uppercase) request"
        d << "    to a path that matches:"
        d << ""

        d <<< "        /"

        for parameter in parameters {
            switch parameter {
            case .path(_):
                d <<< "<path>/"
            case .wildcard(_):
                d <<< "{wildcard}/"
            }
        }
        
        d << ""
        
        d <<< "*/"
        
        return d
    }
}
