import HTTP

/// Error thrown during instantiation of the `CORSConfiguration`.
public enum CORSConfigurationError: Error {

    /// Configuration file could not be found.
    case configurationFileNotFound

    /// A required key is missing in the configuration file. The associated value is the key name.
    case missingRequiredConfigurationKey(String)
}

/// Option for the allow origin header in responses for CORS requests.
///
/// - none: Disallows any origin.
/// - originBased: Uses value of the origin header in the request.
/// - all: Uses wildcard to allow any origin.
/// - custom: Uses custom string provided as an associated value.
public enum AllowOriginSetting {

    /// Disallow any origin.
    case none

    /// Uses value of the origin header in the request.
    case originBased

    /// Uses wildcard to allow any origin.
    case all

    /// Uses custom string provided as an associated value.
    case custom(String)

    /// Creates the header string depending on the case of self.
    ///
    /// - Parameter request: Request for which the allow origin header should be created.
    /// - Returns: Header string to be used in response for allowed origin.
    public func header(forRequest request: Request) -> String {
        switch self {
        case .none: return ""
        case .originBased: return request.headers["Origin"] ?? ""
        case .all: return "*"
        case .custom(let string):
            guard let origin = request.headers["Origin"] else {
                return string
            }
            return string.contains(origin) ? origin : string
        }
    }
}

/// Configuration used for populating headers in response for CORS requests.
public struct CORSConfiguration {

    /// Default CORS configuration.
    ///
    /// - Allow Origin: Based on request's `Origin` value.
    /// - Allow Methods: `GET`, `POST`, `PUT`, `OPTIONS`, `DELETE`, `PATCH`
    /// - Allow Headers: `Accept`, `Authorization`, `Content-Type`, `Origin`, `X-Requested-With`
    public static let `default` = CORSConfiguration(
        allowedOrigin: .originBased,
        allowedMethods: [.get, .post, .put, .options, .delete, .patch],
        allowedHeaders: ["Accept", "Authorization", "Content-Type", "Origin", "X-Requested-With"]
    )


    /// Setting that controls which origin values are allowed.
    public let allowedOrigin: AllowOriginSetting

    /// Header string containing methods that are allowed for a CORS request response.
    public let allowedMethods: String

    /// Header string containing headers that are allowed in a response for CORS request.
    public let allowedHeaders: String

    /// If set to yes, cookies and other credentials will be sent in the response for CORS request.
    public let allowCredentials: Bool

    /// Optionally sets expiration of the cached pre-flight request. Value is in seconds.
    public let cacheExpiration: Int?

    /// Headers exposed in the response of pre-flight request.
    public let exposedHeaders: String?

    /// Instantiate a CORSConfiguration struct that can be used to create a `CORSConfiguration`
    /// middleware for adding support for CORS in your responses.
    ///
    /// - Parameters:
    ///   - allowedOrigin: Setting that controls which origin values are allowed.
    ///   - allowedMethods: Methods that are allowed for a CORS request response.
    ///   - allowedHeaders: Headers that are allowed in a response for CORS request.
    ///   - allowCredentials: If cookies and other credentials will be sent in the response.
    ///   - cacheExpiration: Optionally sets expiration of the cached pre-flight request in seconds.
    ///   - exposedHeaders: Headers exposed in the response of pre-flight request.
    public init(
        allowedOrigin: AllowOriginSetting,
        allowedMethods: [Method],
        allowedHeaders: [String],
        allowCredentials: Bool = false,
        cacheExpiration: Int? = 600,
        exposedHeaders: [String]? = nil
    ) {
        self.allowedOrigin = allowedOrigin
        self.allowedMethods = allowedMethods.map({ $0.description }).joined(separator: ", ")
        self.allowedHeaders = allowedHeaders.joined(separator: ", ")
        self.allowCredentials = allowCredentials
        self.cacheExpiration = cacheExpiration
        self.exposedHeaders = exposedHeaders?.joined(separator: ", ")
    }
}

extension CORSConfiguration: ConfigInitializable {

    /// Creates the CORS configuration of the the Vapor's settings config dictionary.
    /// This enables setting up CORS using a .json configuration file in the project.
    ///
    /// - Parameter config: The settings config dictionary that should be used to extract settings.
    /// - Throws: Node extraction errors, if extraction fails.
    public init(config: Configs.Config) throws {
        guard let cors = config["cors"] else {
            throw ConfigError.missingFile("cors")
        }

        // Allowed origin
        do {
            let originString: String = try cors.get("allowedOrigin")
            switch originString.lowercased() {
            case "all", "*": allowedOrigin = .all
            case "none", "": allowedOrigin = .none
            case "origin": allowedOrigin = .originBased
            default: allowedOrigin = .custom(originString)
            }
        } catch {
            throw CORSConfigurationError.missingRequiredConfigurationKey("allowedOrigin")
        }

        // Get methods
        do {
            let methodArray: [String] = try cors.get("allowedMethods")
            allowedMethods = methodArray.joined(separator: ", ").uppercased()
        } catch {
            throw CORSConfigurationError.missingRequiredConfigurationKey("allowedMethods")
        }

        // Get allowed headers
        do {
            let headersArray: [String] = try cors.get("allowedHeaders")
            allowedHeaders = headersArray.joined(separator: ", ")
        } catch {
            throw CORSConfigurationError.missingRequiredConfigurationKey("allowedHeaders")
        }

        // Allow credentials
        allowCredentials = try cors.get("allowCredentials") ?? false

        // Cache expiration
        cacheExpiration = try cors.get("cacheExpiration") ?? 600

        if let exposedHeaders = cors["exposedHeaders"] {
            switch exposedHeaders.wrapped {
            case .string(let string):
                self.exposedHeaders = string
            case .array(let array):
                #if swift(>=4.1)
                self.exposedHeaders = array.compactMap { $0.string }.joined(separator: ", ")
                #else
                self.exposedHeaders = array.flatMap { $0.string }.joined(separator: ", ")
                #endif
            default:
                throw CORSConfigurationError.missingRequiredConfigurationKey("`exposedHeaders` must be either a string or an array of strings.")
            }
        } else {
            self.exposedHeaders = nil
        }
    }
}
