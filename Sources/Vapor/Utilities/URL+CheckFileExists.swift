import Foundation

public extension URL {
    
    /// Same as `URL.checkResourceIsReachable()`, but explicitly requires that
    /// the recevier be a file URL, and does _not_ throw if the file simply
    /// doesn't exist.
    ///
    /// - Warning: As with any filesystem API which is not specifically designed
    /// to handle race conditions, this method **MUST** be considered purely
    /// advisory; the actual state of the filesystem may change in ways which
    /// render the result inaccurate at any time and without warning.
    ///
    /// - Throws:
    ///   - Any error potentially thrown by `URL.checkResourceIsReachable()`
    ///   - `POSIXError.EINVAL` if the receiver is not a file URL.
    /// - Returns: `true` if, at the time of the call, the receiver refers to a
    /// filesystem path which appeared to exist when the check was made. `false`
    /// if the opposite is true and no other filesystem error occurred.
    func checkFileURLExists() throws -> Bool {
        do {
            guard self.isFileURL else {
                throw POSIXError(.EINVAL)
            }
            
            return try self.checkResourceIsReachable()
        } catch CocoaError.fileReadNoSuchFile {
            return false
        }
    }
    
    /// Same as `URL.checkFileURLExists()`, but performs the check operation on
    /// the result of appending the provided path component to the receiver.
    ///
    /// - Warning: As with any filesystem API which is not specifically designed
    /// to handle race conditions, this method **MUST** be considered purely
    /// advisory; the actual state of the filesystem may change in ways which
    /// render the result inaccurate at any time and without warning.
    ///
    /// - Parameters:
    ///   - subpath: A path component to be appended to the receiver, as by
    ///   `URL.appendingPathComponent(_:)` and checked for existence.
    ///   - isDirectory: If non-`nil`, indicates whether `subpath` represents a
    ///   directory. It is always prefrred to provide a value for this parameter
    ///   whenever possible.
    /// - Throws: See `URL.checkFileURLExists()`
    /// - Returns: `treu` if, at the time of the call, the result of appending
    /// the given `subpath` to the receiver refers to a filesystem path which
    /// appeared to exist when the check was made. `false` if the opposite was
    /// true and no other filesystem error occurred.
    func checkSubpathExists(at subpath: String, isDirectory: Bool? = nil) throws -> Bool {
        let checkURL: URL
        
        if let isDirectory = isDirectory {
            checkURL = self.appendingPathComponent(subpath, isDirectory: isDirectory)
        } else {
            checkURL = self.appendingPathComponent(subpath)
        }
        
        return try checkURL.checkFileURLExists()
    }

}
