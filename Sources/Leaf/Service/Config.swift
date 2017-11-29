import Async
import Core

/// Used to configure Leaf renderer.
public struct LeafConfig {
    /// Create a file reader & cache for the supplied queue
    public typealias FileFactory = (Worker) -> (FileReader & FileCache)
    
    let tags: [String: LeafTag]
    let viewsDir: String
    let fileFactory: FileFactory
    let cache: Bool
    
    public init(
        tags: [String: LeafTag] = defaultTags,
        viewsDir: String = "/",
        cache: Bool = true,
        fileFactory: @escaping FileFactory = File.init
        ) {
        self.tags = tags
        self.viewsDir = viewsDir
        self.fileFactory = fileFactory
        self.cache = cache
    }
}
