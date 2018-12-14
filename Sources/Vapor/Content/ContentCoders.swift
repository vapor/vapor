//import HTTP
//
///// Stores configured `HTTPMessage` and `Data` coders.
/////
///// Use the `require...` methods to fetch coders by `MediaType`.
//public struct ContentCoders: ServiceType {
//    /// See `ServiceType`.
//    public static func makeService(for worker: Container) throws -> ContentCoders {
//        return try worker.make(ContentConfig.self).resolve(on: worker)
//    }
//
//    /// Configured `HTTPMessageEncoder`s.
//    private let httpEncoders: [MediaType: HTTPMessageEncoder]
//
//    /// Configured `HTTPMessageDecoder`s.
//    private var httpDecoders: [MediaType: HTTPMessageDecoder]
//
//    /// Configured `DataEncoder`s.
//    private var dataEncoders: [MediaType: DataEncoder]
//
//    /// Configured `DataDecoder`s.
//    private var dataDecoders: [MediaType: DataDecoder]
//
//    /// Internal init for creating a `ContentCoders`.
//    internal init(
//        httpEncoders: [MediaType: HTTPMessageEncoder],
//        httpDecoders: [MediaType: HTTPMessageDecoder],
//        dataEncoders: [MediaType: DataEncoder],
//        dataDecoders: [MediaType: DataDecoder]
//    ) {
//        self.httpEncoders = httpEncoders
//        self.httpDecoders = httpDecoders
//        self.dataEncoders = dataEncoders
//        self.dataDecoders = dataDecoders
//    }
//
//    /// Returns an `HTTPMessageEncoder` for the specified `MediaType` or throws an error.
//    ///
//    ///     let coder = try coders.requireHTTPEncoder(for: .json)
//    ///
//    /// - parameters:
//    ///     - HTTPMediaType: An encoder for this `MediaType` will be returned.
//    public func requireHTTPEncoder(for HTTPMediaType: HTTPMediaType) throws -> HTTPMessageEncoder {
//        guard let encoder = httpEncoders[mediaType] else {
//            throw Abort(.unsupportedMediaType, identifier: "httpEncoder", suggestedFixes: [
//                "Register an `HTTPMessageEncoder` using `ContentConfig`.",
//                "Use one of the encoding methods that accepts a custom encoder."
//            ])
//        }
//
//        return encoder
//    }
//
//    /// Returns a `HTTPMessageDecoder` for the specified `MediaType` or throws an error.
//    ///
//    ///     let coder = try coders.requireHTTPDecoder(for: .json)
//    ///
//    /// - parameters:
//    ///     - HTTPMediaType: A decoder for this `MediaType` will be returned.
//    public func requireHTTPDecoder(for HTTPMediaType: HTTPMediaType) throws -> HTTPMessageDecoder {
//        guard let decoder = httpDecoders[mediaType] else {
//            throw Abort(.unsupportedMediaType, identifier: "httpDecoder", suggestedFixes: [
//                "Register an `HTTPMessageDecoder` using `ContentConfig`.",
//                "Use one of the decoding methods that accepts a custom decoder."
//            ])
//        }
//
//        return decoder
//    }
//
//    /// Returns a `DataEncoder` for the specified `MediaType` or throws an error.
//    ///
//    ///     let coder = try coders.requireDataEncoder(for: .json)
//    ///
//    /// - parameters:
//    ///     - HTTPMediaType: An encoder for this `MediaType` will be returned.
//    public func requireDataEncoder(for HTTPMediaType: HTTPMediaType) throws -> DataEncoder {
//        guard let encoder = dataEncoders[mediaType] else {
//            throw Abort(.unsupportedMediaType, identifier: "dataEncoder", suggestedFixes: [
//                "Register an `DataEncoder` using `ContentConfig`.",
//                "Use one of the encoding methods that accepts a custom encoder."
//            ])
//        }
//
//        return encoder
//    }
//
//    /// Returns a `DataDecoder` for the specified `MediaType` or throws an error.
//    ///
//    ///     let coder = try coders.requireDataDecoder(for: .json)
//    ///
//    /// - parameters:
//    ///     - HTTPMediaType: A decoder for this `MediaType` will be returned.
//    public func requireDataDecoder(for HTTPMediaType: HTTPMediaType) throws -> DataDecoder {
//        guard let decoder = dataDecoders[mediaType] else {
//
//            throw Abort(.unsupportedMediaType, identifier: "dataDecoder", suggestedFixes: [
//                "Register an `DataDecoder` using `ContentConfig`.",
//                "Use one of the decoding methods that accepts a custom decoder."
//            ])
//        }
//
//        return decoder
//    }
//}
