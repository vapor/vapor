import Async
import Core

/// Used to configure Leaf renderer.
public struct LeafConfig {
    /// Create a file reader & cache for the supplied queue
    public typealias FileFactory = (Worker) -> (FileReader & FileCache)
    
    /// All registered leaf tags
    let tags: [String: LeafTag]
    
    /// The directory to read templates from
    let viewsDir: String
    
    /// A filefactory can create a new FileReader
    let fileFactory: FileFactory
    
    /// If `true`, the read files should be cached in the fileReader
    let shouldCache: Bool
    
    /// Creates a new Leaf configuration
    public init(
        tags: [String: LeafTag] = defaultTags,
        viewsDir: String = "/",
        shouldCache: Bool = true,
        fileFactory: @escaping FileFactory = BasicFileReader.init
    ) {
        self.tags = tags
        self.viewsDir = viewsDir
        self.fileFactory = fileFactory
        self.shouldCache = shouldCache
    }
}
