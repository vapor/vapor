import HTTPTypes
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Captures all errors and transforms them into an internal server error HTTP response.
public final class ErrorMiddleware: Middleware {
    /// Structure of `ErrorMiddleware` default response.
    internal struct ErrorResponse: Codable {
        /// Always `true` to indicate this is a non-typical JSON response.
        var error: Bool

        /// The reason for the error.
        var reason: String
    }

    /// Create a default `ErrorMiddleware`. Logs each error at its `DebuggableError/logLevel`, or `.debug` for
    /// an error that isn't a `DebuggableError`, and converts `Error` to `Response` based on `Environment` and on
    /// conformance to `AbortError` and `Debuggable`.
    ///
    /// To report errors at a different level, give them a `logLevel` or use your own `ErrorMiddleware`.
    ///
    /// - parameters:
    ///     - environment: The environment to respect when presenting errors.
    public static func `default`(environment: Environment) -> ErrorMiddleware {
        return .init { req, error in
            let status: HTTPResponse.Status
            let reason: String
            let source: ErrorSource
            var headers: HTTPFields

            // Inspect the error type and extract what data we can.
            switch error {
            case let debugAbort as (any DebuggableError & AbortError):
                (reason, status, headers, source) = (
                    debugAbort.reason, debugAbort.status, debugAbort.headers, debugAbort.source ?? .capture()
                )

            case let abort as any AbortError:
                (reason, status, headers, source) = (abort.reason, abort.status, abort.headers, .capture())

            case let debugErr as any DebuggableError:
                (reason, status, headers, source) = (debugErr.reason, .internalServerError, [:], debugErr.source ?? .capture())

            default:
                // In debug mode, provide the error description; otherwise hide it to avoid sensitive data disclosure.
                reason = environment.isRelease ? "Something went wrong." : String(describing: error)
                (status, headers, source) = (.internalServerError, [:], .capture())
            }

            // Report the error at the level it asks for. Errors answered here are handled, and most are the
            // client's doing (a missing route, a bad credential, a truncated upload) rather than anything the
            // server needs to act on, so one that doesn't ask only shows up when debugging.
            Logger.current.report(
                error: error,
                level: (error as? any DebuggableError)?.logLevel ?? .debug,
                metadata: [
                    "method": "\(req.method.rawValue)",
                    "url": "\(req.url.string)",
                    "userAgent": .array(req.headers[values: .userAgent].map { "\($0)" }),
                ],
                file: source.file,
                function: source.function,
                line: source.line)

            // attempt to serialize the error to json
            let body: Response.Body
            do {
                let encoder = try req.contentConfiguration.requireEncoder(for: .json)
                var data = Data()
                try encoder.encode(ErrorResponse(error: true, reason: reason), to: &data, headers: &headers, userInfo: [:])

                body = .init(
                    data: data,
                )
            } catch {
                body = .init(string: "Oops: \(String(describing: error))\nWhile encoding error: \(reason)")
                headers.contentType = .plainText
            }

            // create a Response with appropriate status
            return Response(status: status, headers: headers, body: body)
        }
    }

    /// Error-handling closure.
    private let closure: @Sendable (Request, any Error) -> (Response)

    /// Create a new `ErrorMiddleware`.
    ///
    /// - parameters:
    ///     - closure: Error-handling closure. Converts `Error` to `Response`.
    public init(_ closure: @Sendable @escaping (Request, any Error) -> (Response)) {
        self.closure = closure
    }

    public func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            return self.closure(request, error)
        }
    }
}
