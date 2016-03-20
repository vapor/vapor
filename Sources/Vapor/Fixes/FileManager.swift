import libc

class FileManager {
	enum Error: ErrorType {
		case CouldNotOpenFile
		case Unreadable
	}

	static func readBytesFromFile(path: String) throws -> [UInt8] {
        let fd = open(path, O_RDONLY);

        if fd < 0 {
        	throw Error.CouldNotOpenFile
        }
        defer {
            close(fd)
        }

        var info = stat()
        let ret = withUnsafeMutablePointer(&info) { infoPointer -> Bool in
            if fstat(fd, infoPointer) < 0 {
                return false
            }
            return true
        }
        
        if !ret {
        	throw Error.Unreadable
        }
        
        let length = Int(info.st_size)
        
        let rawData = malloc(length)
        var remaining = Int(info.st_size)
        var total = 0
        while remaining > 0 {
        	//change to advanced(by:)
            let amt = read(fd, rawData.advancedBy(total), remaining)
            if amt < 0 {
                break
            }
            remaining -= amt
            total += amt
        }

        if remaining != 0 {
            throw Error.Unreadable
        }

        //thanks @Danappelxx
        let data = UnsafeMutablePointer<UInt8>(rawData)
        let buffer = UnsafeMutableBufferPointer<UInt8>(start: data, count: length)
        return Array(buffer)
    }

    static func fileExistsAtPath(path: String, isDirectory: inout Bool) -> Bool {
		var s = stat()
        if lstat(path, &s) >= 0 {
            if (s.st_mode & S_IFMT) == S_IFLNK {
                if stat(path, &s) >= 0 {
                    isDirectory = (s.st_mode & S_IFMT) == S_IFDIR
                } else {
                    return false
                }
            } else {
                isDirectory = (s.st_mode & S_IFMT) == S_IFDIR
            }

            // don't chase the link for this magic case -- we might be /Net/foo
            // which is a symlink to /private/Net/foo which is not yet mounted...
            if (s.st_mode & S_IFMT) == S_IFLNK {
                if (s.st_mode & S_ISVTX) == S_ISVTX {
                    return true
                }
                // chase the link; too bad if it is a slink to /Net/foo
                stat(path, &s) >= 0
            }
        } else {
            return false
        }
        return true
	}
}