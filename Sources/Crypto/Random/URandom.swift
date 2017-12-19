import COperatingSystem
import Foundation

/// URandom represents a file connection to /dev/urandom on Unix systems.
/// /dev/urandom is a cryptographically secure random generator provided by the OS.
///
/// [Learn More →](https://docs.vapor.codes/3.0/crypto/random/)
public final class URandom: RandomProtocol {
    public enum Error: Swift.Error {
        case open(Int32)
        case read(Int32)
    }

    private let file: UnsafeMutablePointer<FILE>

    /// Initialize URandom
    public init(path: String) throws {
        guard let file = fopen(path, "rb") else {
            // The Random protocol doesn't allow init to fail, so we have to
            // check whether /dev/urandom was successfully opened here
            throw Error.open(errno)
        }
        self.file = file
    }

    deinit {
        fclose(file)
    }

    fileprivate func read(numData: Int) throws -> [UInt8] {
        // Initialize an empty array with space for numData bytes
        var bytes = [UInt8](repeating: 0, count: numData)
        guard fread(&bytes, 1, numData, file) == numData else {
            // If the requested number of random bytes couldn't be read,
            // we need to throw an error
            throw Error.read(errno)
        }

        return bytes
    }

    /// Get a random array of Data
    public func data(count: Int) throws -> Data {
        return Data(try read(numData: count))
    }
    
    public convenience init() throws {
        try self.init(path: "/dev/urandom")
    }
}
