extension Request {
    public var view: ViewRenderer {
        self.application.view.for(self)
    }
}

extension Application {
    public var view: ViewRenderer {
        self.views.renderer
    }
    
    public var views: Views {
        self.providers.require(Views.self)
    }
}

public final class Views: Provider {
    public let application: Application
    
    private var factory: (() -> (ViewRenderer))?
    
    public init(_ application: Application) {
        self.application = application
    }
    
    public var plaintext: PlaintextRenderer {
        return .init(
            fileio: self.application.fileio,
            viewsDirectory: self.application.directory.viewsDirectory,
            logger: self.application.logger,
            eventLoopGroup: self.application.eventLoopGroup
        )
    }
    
    public var renderer: ViewRenderer {
        if let factory = self.factory {
            return factory()
        } else {
            return self.plaintext
        }
    }
    
    public func use(_ factory: @escaping () -> (ViewRenderer)) {
        self.factory = factory
    }
}
