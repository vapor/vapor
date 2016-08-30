@_exported import PathIndexable

extension Config: PathIndexable {

    /**
     If self is an array representation, return array
     */
    public var pathIndexableArray: [Config]? {
        return node.pathIndexableArray?.map { Config($0) }
    }

    /**
     If self is an object representation, return object
     */
    public var pathIndexableObject: [String: Config]? {
        guard case let .object(o) = node else { return nil }
        var object: [String: Config] = [:]
        for (key, val) in o {
            object[key] = Config(val)
        }
        return object
    }

    /**
     Initialize json w/ array
     */
    public init(_ array: [Config]) {
        let array = array.map { $0.node }
        let node = Node.array(array)
        self.init(node)
    }

    /**
     Initialize json w/ object
     */
    public init(_ o: [String: Config]) {
        var object: [String: Node] = [:]
        for (key, val) in o {
            object[key] = val.node
        }
        let node = Node.object(object)
        self.init(node)
    }
}
