import Async
import Core
import Dispatch
import Foundation
import Service

/// Used to configure Leaf renderer.
public struct LeafConfig {
    let tags: [String: Tag]
    let fileFactory: Renderer.FileFactory

    public init(
        tags: [String: Tag],
        fileFactory: @escaping Renderer.FileFactory
    ) {
        self.tags = tags
        self.fileFactory = fileFactory
    }

    public static func `default`() -> LeafConfig {
        return LeafConfig(
            tags: defaultTags
        ) { queue in
            return File(queue: queue)
        }
    }
}

public final class Provider: Service.Provider {
    /// See Service.Provider.repositoryName
    public static let repositoryName = "leaf"

    public init() {}

    /// See Service.Provider.Register
    public func register(_ services: inout Services) throws {
        services.register(ViewRenderer.self) { container -> Leaf.Renderer in
            let config = try container.make(LeafConfig.self, for: Renderer.self)
            return Leaf.Renderer(
                tags: config.tags,
                fileFactory: config.fileFactory
            )
        }

        services.register { container in
            return LeafConfig.default()
        }
    }

    /// See Service.Provider.boot
    public func boot(_ container: Container) throws { }
}


// MARK: View

public struct View {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }
}


public protocol ViewRenderer {
    func make(_ path: String, context: Encodable, on queue: DispatchQueue) throws -> Future<View>
}
