import Foundation
import libc

/**
    A replacement for Foundation's NSFileManager using
    implementation from Swift's core libraries.
*/
class FileManager {
    enum Error: ErrorProtocol {
        case CouldNotOpenFile
        case Unreadable
    }

    static func readBytesFromFile(_ path: String) throws -> [UInt8] {
        let data = NSData(contentsOfFile: path)
        print("Loaded data: \(data)")
        let byteArray = data?.byteArray ?? []
        print("Byte array: \(byteArray)")
        let string = String.init(data: byteArray) ?? "<unknown>"
        print("Got json string: \n\n\n********\n\n\(string)\n\n********\n\n\n")
        return byteArray
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
                stat(path, &s) >= 0
            }
        } else {
            return (false, isDirectory)
        }
        return (true, isDirectory)
    }

    static func expandPath(_ path: String) throws -> String {
        let result = realpath(path, nil)

        guard result != nil else {
            print("Expand path 1")
            throw Error.Unreadable
        }

        defer { free(result) }

        let cstring = String(validatingUTF8: result)

        if let expanded = cstring {
            return expanded
        } else {
            print("Expand path 2")
            throw Error.Unreadable
        }
    }

    static func contentsOfDirectory(_ path: String) throws -> [String] {
        var gt = glob_t()
        defer { globfree(&gt) }

        let path = try self.expandPath(path).finish("/")
        let pattern = strdup(path + "{*,.*}")

        switch glob(pattern, GLOB_MARK | GLOB_NOSORT | GLOB_BRACE, nil, &gt) {
        case GLOB_NOMATCH:
            return [ ]
        case GLOB_ABORTED:
            print("Contents of directory 1")
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

/*
 testSimple : Linux : 
    Test Case 'ConfigTests.testSimple' started at 23:33:55.133
        Loaded data: 
            Optional(<7b0a0922 64656275 67223a20 74727565 2c0a0922 706f7274 223a2038 3030302c 
                      0a0a0922 6e657374 6564223a 207b0a09 09226122 3a202261 222c0a09 09226222
                      3a202262 222c0a09 09226322 3a207b0a 09090922 74727565 223a2074 7275650a 
                      09097d0a 097d0a7d 0a>)
            Byte array: [
                123, 10, 9, 34, 100, 101, 98, 117, 103, 34, 58, 32, 116, 114, 117, 101, 44, 10, 9,
                34, 112, 111, 114, 116, 34, 58, 32, 56, 48, 48, 48, 44, 10, 10, 9, 34, 110, 101, 
                115, 116, 101, 100, 34, 58, 32, 123, 10, 9, 9, 34, 97, 34, 58, 32, 34, 97, 34, 44,
                10, 9, 9, 34, 98, 34, 58, 32, 34, 98, 34, 44, 10, 9, 9, 34, 99, 34, 58, 32, 123, 
                10, 9, 9, 9, 34, 116, 114, 117, 101, 34, 58, 32, 116, 114, 117, 101, 10, 9, 9, 125, 
                10, 9, 125, 10, 125, 10
            ]
 testSimple :  osx  : 
    Test Case '-[VaporTestSuite.ConfigTests testSimple]' started.
        Loaded data:
            Optional(<7b0a0922 64656275 67223a20 74727565 2c0a0922 706f7274 223a2038 3030302c
                      0a0a0922 6e657374 6564223a 207b0a09 09226122 3a202261 222c0a09 09226222
                      3a202262 222c0a09 09226322 3a207b0a 09090922 74727565 223a2074 7275650a
                      09097d0a 097d0a7d 0a>)
            Byte array: [
                123, 10, 9, 34, 100, 101, 98, 117, 103, 34, 58, 32, 116, 114, 117, 101, 44, 10, 9,
                34, 112, 111, 114, 116, 34, 58, 32, 56, 48, 48, 48, 44, 10, 10, 9, 34, 110, 101, 
                115, 116, 101, 100, 34, 58, 32, 123, 10, 9, 9, 34, 97, 34, 58, 32, 34, 97, 34, 44, 
                10, 9, 9, 34, 98, 34, 58, 32, 34, 98, 34, 44, 10, 9, 9, 34, 99, 34, 58, 32, 123, 
                10, 9, 9, 9, 34, 116, 114, 117, 101, 34, 58, 32, 116, 114, 117, 101, 10, 9, 9, 125, 
                10, 9, 125, 10, 125, 10]
 */


/*
 Byte array: [
 123, 10, 9, 34, 100, 101, 98, 117, 103, 34, 58, 32, 116, 114, 117, 101, 44, 10, 9,
 123, 10, 9, 34, 100, 101, 98, 117, 103, 34, 58, 32, 116, 114, 117, 101, 44, 10, 9,
 34, 112, 111, 114, 116, 34, 58, 32, 56, 48, 48, 48, 44, 10, 10, 9, 34, 110, 101,
 34, 112, 111, 114, 116, 34, 58, 32, 56, 48, 48, 48, 44, 10, 10, 9, 34, 110, 101,
 115, 116, 101, 100, 34, 58, 32, 123, 10, 9, 9, 34, 97, 34, 58, 32, 34, 97, 34, 44,
 115, 116, 101, 100, 34, 58, 32, 123, 10, 9, 9, 34, 97, 34, 58, 32, 34, 97, 34, 44,
 10, 9, 9, 34, 98, 34, 58, 32, 34, 98, 34, 44, 10, 9, 9, 34, 99, 34, 58, 32, 123,
 10, 9, 9, 34, 98, 34, 58, 32, 34, 98, 34, 44, 10, 9, 9, 34, 99, 34, 58, 32, 123,
 10, 9, 9, 9, 34, 116, 114, 117, 101, 34, 58, 32, 116, 114, 117, 101, 10, 9, 9, 125,
 10, 9, 9, 9, 34, 116, 114, 117, 101, 34, 58, 32, 116, 114, 117, 101, 10, 9, 9, 125,
 10, 9, 125, 10, 125, 10
 10, 9, 125, 10, 125, 10]
 ]
 Byte array: [
 */