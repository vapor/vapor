import Vapor

@available(*, deprecated, renamed: "EventLoopFuture")
public typealias Future = EventLoopFuture

extension EventLoopFuture {
    @available(*, deprecated, renamed: "Value")
    public typealias Expectation = Value

    @available(*, deprecated, message: "The `to` parameter has been removed and this method can no longer throw.")
    public func map<T>(to type: T.Type, _ callback: @escaping (Expectation) throws -> T) -> EventLoopFuture<T> {
        return self.flatMapThrowing(callback)
    }


    @available(*, deprecated, message: "The `to` parameter has been removed and this method can no longer throw.")
    public func flatMap<T>(to type: T.Type, _ callback: @escaping (Expectation) throws -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        return self.flatMap { input in
            do {
                return try callback(input)
            } catch {
                return self.eventLoop.makeFailedFuture(error)
            }
        }
    }

    @available(*, deprecated, renamed: "flatMapErrorThrowing")
    public func catchMap(_ callback: @escaping (Error) throws -> (Expectation)) -> EventLoopFuture<Expectation> {
        return self.flatMapErrorThrowing(callback)
    }


    @available(*, deprecated, message: "Use `flatMapError` with internal do / catch that returns a failed future.")
    public func catchFlatMap(_ callback: @escaping (Error) throws -> (EventLoopFuture<Expectation>)) -> EventLoopFuture<Expectation> {
        return self.flatMapError { inputError in
            do {
                return try callback(inputError)
            } catch {
                return self.eventLoop.makeFailedFuture(error)
            }
        }
    }
}
