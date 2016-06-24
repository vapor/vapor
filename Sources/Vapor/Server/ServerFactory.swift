public class ServerFactory {
    let defaultServer: Server.Type
    let defaultResponder: Responder
    let defaultErrors: ServerErrorHandler
    let console: Console

    init(server: Server.Type, responder: Responder, errors: ServerErrorHandler, console: Console) {
        defaultServer = server
        defaultResponder = responder
        defaultErrors = errors
        self.console = console
    }


}
