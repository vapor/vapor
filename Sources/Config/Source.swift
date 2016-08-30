public enum Source {
    case memory(name: String, config: Node)
    case commandLine
    case directory(root: String)
}
