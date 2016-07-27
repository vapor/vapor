/**
    Multipart data that can consist of a 
    single or multiple files or a single or
    multiple lines of String input.
*/
public enum Multipart {
    case files([File])
    case file(File)
    case input(String)
    case inputArray([String])
}

extension Multipart {
    /**
        A multipart File.
    */
    public struct File {
        public var name: String?
        public var type: String?
        public var data: Bytes
    }
}

/**
    Convenience accessors
*/
extension Multipart {
    public var file: File? {
        if case .file(let file) = self {
            return file
        }

        return nil
    }

    public var files: [File]? {
        if case .files(let files) = self {
            return files
        }

        return nil
    }

    public var input: String? {
        if case .input(let string) = self {
            return string
        }

        return nil
    }

    public var inputArray: [String]? {
        if case .inputArray(let array) = self {
            return array
        }
        
        return nil
    }
}
