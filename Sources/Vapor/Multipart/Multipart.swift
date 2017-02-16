///**
//    Multipart data that can consist of a 
//    single or multiple files or a single or
//    multiple lines of String input.
//*/
//public enum Multipart {
//    case files([File])
//    case file(File)
//    case input(String)
//    case inputArray([String])
//}
//
//extension Multipart {
//    /**
//        A multipart File.
//    */
//    public struct File {
//        public var name: String?
//        public var type: String?
//        public var data: Bytes
//
//        public init(name: String?, type: String?, data: Bytes) {
//            self.name = name
//            self.type = type
//            self.data = data
//        }
//    }
//}
//
///**
//    Convenience accessors
//*/
//extension Multipart {
//    public var file: File? {
//        if case .file(let file) = self {
//            return file
//        }
//
//        return nil
//    }
//
//    public var files: [File]? {
//        switch self {
//        case .files(let files):
//            return files
//        case .file(let file):
//            return [file]
//        default:
//            return nil
//        }
//    }
//
//    public var input: String? {
//        if case .input(let string) = self {
//            return string
//        }
//
//        return nil
//    }
//
//    @available(*, deprecated: 1.0, message: "Use `inputs` instead.")
//    public var inputArray: [String]? {
//        return inputs
//    }
//
//    public var inputs: [String]? {
//        switch self {
//        case .inputArray(let inputs):
//            return inputs
//        case .input(let input):
//            return [input]
//        default:
//            return nil
//        }
//    }
//}
//
//
//public enum MultipartSerializationError: Swift.Error {
//    case missingFileType
//}
//
//extension Multipart {
//    @available(*, deprecated: 1.4, message: "Use `FormData.Serializer` instead.")
//    public func serialized(boundary: String, keyName: String) throws -> Bytes {
//        var serialized = Bytes()
//
//        inputs?.forEach { input in
//            serialized += "--\(boundary)\r\n".makeBytes()
//            serialized += "Content-Disposition: form-data; name=\"\(keyName)\"\r\n\r\n".makeBytes()
//            serialized += input.bytes
//            serialized += "\r\n".makeBytes()
//        }
//
//        try files?.forEach { file in
//            let fileName = file.name ?? ""
//            guard let type = file.type else { throw MultipartSerializationError.missingFileType }
//
//            serialized += "--\(boundary)\r\n".makeBytes()
//            serialized += "Content-Disposition: form-data; name=\"\(keyName)\"; filename=\"\(fileName)\"\r\n".makeBytes()
//            serialized += "Content-Type: \(type)\r\n\r\n".makeBytes()
//            serialized += file.data
//            serialized += "\r\n".makeBytes()
//        }
//
//        // close
//        serialized += "--\(boundary)--\r\n".makeBytes()
//        return serialized
//    }
//}
