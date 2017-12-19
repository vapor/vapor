import Async
import Dispatch
import Foundation
import Service

/// Used to configure Leaf renderer.
public struct LeafConfig {
    let tags: [String: LeafTag]
    let viewsDir: String
    let fileFactory: LeafRenderer.FileFactory

    public init(
        tags: [String: LeafTag] = defaultTags,
        viewsDir: String = "/",
        fileFactory: @escaping LeafRenderer.FileFactory = File.init
    ) {
        self.tags = tags
        self.viewsDir = viewsDir
        self.fileFactory = fileFactory
    }
}

public final class LeafProvider: Provider {
    /// See Service.Provider.repositoryName
    public static let repositoryName = "leaf"

    public init() {}

    /// See Service.Provider.Register
    public func register(_ services: inout Services) throws {
        services.register(ViewRenderer.self) { container -> LeafRenderer in
            let config = try container.make(LeafConfig.self, for: LeafRenderer.self)
            return LeafRenderer(
                config: config,
                on: container
            )
        }

        services.register { container -> LeafConfig in
            let dir = try container.make(DirectoryConfig.self, for: LeafRenderer.self)
            return LeafConfig(viewsDir: dir.workDir + "Resources/Views")
        }
    }

    /// See Service.Provider.boot
    public func boot(_ container: Container) throws { }
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
    /// Renders a view using the supplied encodable context and worker.
    func make<E>(_ path: String, _ context: E) throws -> Future<View>
        where E: Encodable
}

extension ViewRenderer {
    /// Create a view with null context.
    public func make(_ path: String) throws -> Future<View> {
        return try make(path, nil as String?)
    }
}
