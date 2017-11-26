import Async
import Core
import Dispatch
import Foundation
import Service

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

public final class LeafProvider: Provider {
    /// See Service.Provider.repositoryName
    public static let repositoryName = "leaf"

    public init() {}

    /// See Service.Provider.Register
    public func register(_ services: inout Services) throws {
        services.register { container -> LeafConfig in
            let dir = try container.make(DirectoryConfig.self, for: LeafRenderer.self)
            return LeafConfig(viewsDir: dir.workDir + "Resources/Views")
        }
    }

    /// See Service.Provider.boot
    public func boot(_ container: Container) throws { }
}

fileprivate let leafRendererKey = "leaf:renderer"

extension HasContainer where Self: Worker {
    public func makeLeafRenderer() throws -> LeafRenderer {
        if let renderer = self.eventLoop.extend[leafRendererKey] as? LeafRenderer {
            return renderer
        }
        
        let config = try self.workerMake(LeafConfig.self, for: LeafRenderer.self)
        let renderer =  LeafRenderer(
            tags: config.tags,
            viewsDir: config.viewsDir,
            cache: config.cache,
            fileReader: config.fileFactory(self)
        )
        
        self.eventLoop.extend[leafRendererKey] = renderer
        
        return renderer
    }
}

// MARK: View

public struct View: Codable {
    /// The view's data.
    public let data: Data

    /// Create a new View
    public init(data: Data) {
        self.data = data
    }

    /// See Encodable.encode
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }

    /// See Decodable.decode
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(data: container.decode(Data.self))
    }
}

public protocol ViewRenderer {
    func make(_ path: String, context: Encodable, on worker: Worker) throws -> Future<View>
    func make(_ path: String, _ context: [String: Encodable], on worker: Worker) throws -> Future<View>
}
