#if OpenAPI
import HTTPTypes
import Logging
import Synchronization
import Vapor

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Builds the documentation's JSON once the application has booted, when its routes are
/// registered, and serves it.
///
/// The documentation routes hold this rather than the application, so they don't keep it alive.
final class OpenAPIDocumentationBuilder: LifecycleHandler {
    private enum State {
        /// The application hasn't booted since the documentation was registered.
        case pending
        case built(Data)
        /// The document couldn't be built, and the reason a client may be told.
        case failed(reason: String)
    }

    private let info: OpenAPIInfo
    private let state = Mutex<State>(.pending)

    init(info: OpenAPIInfo) {
        self.info = info
    }

    /// Builds the document. A route that can't be described is logged rather than thrown, so
    /// the documentation can't stop the application from starting.
    func didBoot(_ application: Application) async {
        let built: State
        do {
            built = .built(try application.routes.openAPI(info: info).json())
        } catch {
            Logger.current.error("The OpenAPI document couldn't be built, so openapi.json responds with 500. \(error)")
            // Released apps don't tell clients about their routes and types, as ErrorMiddleware.
            let reason = application.environment.isRelease ? "See the application's log." : "\(error)"
            built = .failed(reason: reason)
        }
        state.withLock { $0 = built }
    }

    /// The JSON as a response: a 500 naming the route if one couldn't be described, or a 503
    /// until the application has booted.
    func response() throws -> Response {
        switch state.withLock({ $0 }) {
        case .built(let json):
            return .openAPIJSON(json)
        case .failed(let reason):
            throw Abort(.internalServerError, reason: "The OpenAPI document couldn't be built. \(reason)")
        case .pending:
            throw Abort(
                .serviceUnavailable,
                reason:
                    "The OpenAPI document is built when the application boots. Was the documentation registered after it booted?"
            )
        }
    }
}

extension Response {
    /// A response carrying an OpenAPI document's JSON.
    static func openAPIJSON(_ json: Data) -> Response {
        var headers = HTTPFields()
        headers.contentType = .json
        return Response(headers: headers, body: .init(data: json))
    }
}
#endif
