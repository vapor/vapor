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

    static func fileAtPath(path: String) -> (exists: Bool, isDirectory: Bool) {
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

	static func expandPath(path: String) throws -> String {
		let result = realpath(path, nil)

		guard result != nil else {
			throw Error.Unreadable
		}

		defer { free(result) }

		if let expanded = String.fromCString(result) {
			return expanded
		} else {
			throw Error.Unreadable
		}
	}

	static func contentsOfDirectory(path: String) throws -> [String] {
		var gt = glob_t()
		defer { globfree(&gt) }

		let path = try self.expandPath(path).finish("/")
		let pattern = strdup(path + "*")

		switch glob(pattern, GLOB_MARK | GLOB_NOSORT, nil, &gt) {
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
			if let path = String.fromCString(gt.gl_pathv[i]) {
				contents.append(path)
			}
		}

		return contents
	}

}
