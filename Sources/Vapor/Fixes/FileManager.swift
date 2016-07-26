import Foundation
import libc

/**
    A replacement for Foundation's NSFileManager using
    implementation from Swift's core libraries.
*/
class FileManager {
    enum Error: Swift.Error {
        case CouldNotOpenFile
        case Unreadable
    }

    static func readBytesFromFile(_ path: String) throws -> [UInt8] {
        guard let data = NSData(contentsOfFile: path) else {
            throw Error.CouldNotOpenFile
        }
        return data.byteArray 
    }

    static func fileAtPath(_ path: String) -> (exists: Bool, isDirectory: Bool) {
        var isDirectory = false
        var s = stat()
        if lstat(path, &s) >= 0 {
            if (s.st_mode & S_IFMT) == S_IFLNK {
                if stat(path, &s) >= 0 {
                    isDirectory = (s.st_mode & S_IFMT) == S_IFDIR
                } else {
                    return (false, isDirectory)
                }
            } else {
                isDirectory = (s.st_mode & S_IFMT) == S_IFDIR
            }

            // don't chase the link for this magic case -- we might be /Net/foo
            // which is a symlink to /private/Net/foo which is not yet mounted...
            if (s.st_mode & S_IFMT) == S_IFLNK {
                if (s.st_mode & S_ISVTX) == S_ISVTX {
                    return (true, isDirectory)
                }
                // chase the link; too bad if it is a slink to /Net/foo
                let _ = stat(path, &s) >= 0
            }
        } else {
            return (false, isDirectory)
        }
        return (true, isDirectory)
    }

    static func expandPath(_ path: String) throws -> String {
        let maybeResult = realpath(path, nil)

        guard let result = maybeResult else {
            throw Error.Unreadable
        }

        defer { free(result) }

        let cstring = String(validatingUTF8: result)

        if let expanded = cstring {
            return expanded
        } else {
            throw Error.Unreadable
        }
    }

    static func contentsOfDirectory(_ path: String) throws -> [String] {
        var gt = glob_t()
        defer { globfree(&gt) }

        let path = try self.expandPath(path).finished(with: "/")
        let pattern = strdup(path + "{*,.*}")

        switch glob(pattern, GLOB_MARK | GLOB_NOSORT | GLOB_BRACE, nil, &gt) {
        case GLOB_NOMATCH:
            return [ ]
        case GLOB_ABORTED:
            throw Error.Unreadable
        default:
            break
        }

        var contents = [String]()
        let count: Int

        #if os(Linux)
            count = Int(gt.gl_pathc)
        #else
            count = Int(gt.gl_matchc)
        #endif

        for i in 0..<count {
            guard let utf8 = gt.gl_pathv[i] else { continue }
            let cstring = String(validatingUTF8: utf8)
            if let path = cstring {
                contents.append(path)
            }
        }

        return contents
    }

}
