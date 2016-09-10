import JSON

public extension Node {
    /**
     Load the file at a path as raw bytes or as parsed JSON representation
    */
    init(path: String) throws {
        let data = try DataFile().load(path: path)
        if path.hasSuffix(".json") {
            self = try JSON(bytes: data).converted()
        } else {
            self = .bytes(data)
        }
    }
}
