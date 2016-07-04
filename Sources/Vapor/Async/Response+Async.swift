#if !os(Linux)

    import Foundation

    /*
     Temporarily not available on Linux until Foundation's 'Dispatch apis are available
     */
    extension Response {
        public static func async(timingOut timeout: DispatchTime = .distantFuture, _ handler: (Promise<ResponseRepresentable>) throws -> Void) throws -> ResponseRepresentable {
            return try Promise.async(timingOut: timeout, handler)
        }
    }
#endif
