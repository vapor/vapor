import Foundation
import Dispatch

// Indirect so futures can be nested
public indirect enum FutureResult<Expectation> {
    case error(Error)
    case expectation(Expectation)

    /// Returns the result error or
    /// nil if the result contains expectation.
    public var error: Error? {
        switch self {
        case .error(let error):
            return error
        default:
            return nil
        }
    }

    /// Returns the result expectation or
    /// nil if the result contains an error.
    public var expectation: Expectation? {
        switch self {
        case .expectation(let expectation):
            return expectation
        default:
            return nil
        }
    }
    
    /// Throws an error if this contains an error, returns the Expectation otherwise
    public func unwrap() throws -> Expectation {
        switch self {
        case .expectation(let data):
            return data
        case .error(let error):
            throw error
        }
    }
}
