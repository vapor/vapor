public enum Source {
    case memory(name: String, config: Node)
    case commandline
    case directory(root: String)
}
