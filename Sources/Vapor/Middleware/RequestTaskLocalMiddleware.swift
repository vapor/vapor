
extension Request {
    /// The request associated with this task.
    ///
    /// The recommended way to set this task-local value is by adding ``RequestTaskLocalMiddleware`` to your app's middleware stack.
    @TaskLocal public static var current: Request?

    /// The request associated with this task.
    ///
    /// The recommended way to set this task-local value is by adding ``RequestTaskLocalMiddleware`` to your app's middleware stack.
    ///
    /// - Throws: When no task-local request is found.
    public static var requireCurrent: Request {
        get throws {
            guard let current else {
                throw Abort(
                    .internalServerError,
                    reason: "Task local Vapor.Request not found, make sure you added RequestTaskLocalMiddleware."
                )
            }
            return current
        }
    }
}

/// A middleware that injects the ``Request`` into the task-local value ``Request/current``.
///
/// Task-local propagation allows the current task hierarchy to inspect the request in downstream
/// middlewares and the request handler.
public struct RequestTaskLocalMiddleware: AsyncMiddleware {

    /// Creates a new middleware.
    public init() {}

    public func respond(
        to request: Request,
        chainingTo next: any AsyncResponder
    ) async throws -> Response {
        try await Request.$current.withValue(request) {
            try await next.respond(to: request)
        }
    }
}
