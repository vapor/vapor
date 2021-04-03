private struct TrieRouterFactory: RouterFactory {
    typealias ConfigurationOption<Output> = TrieRouter<Output>.ConfigurationOption
    
    let routes: Routes
    
    func buildRouter<Output>(forOutputType type: Output.Type) -> AnyRouter<Output> {
        let options: Set<ConfigurationOption<Output>> = routes.caseInsensitive ? [.caseInsensitive] : []
        return TrieRouter(Output.self, options: options).eraseToAnyRouter()
    }
}

extension Application.Router {
    public var trie: RouterFactory {
        return TrieRouterFactory(routes: self.application.routes)
    }
}

extension Application.Router.Provider {
    public static var trie: Self {
        .init {
            $0.router.use { $0.router.trie }
        }
    }
}
