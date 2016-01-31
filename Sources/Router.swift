//
// Based on HttpRouter from Swifter (https://github.com/glock45/swifter) by Damian Kołakowski.
//

import Foundation

class Router {

    private class Node {
        var nodes = [String: Node]()
        var syncHandler: (Request -> Response)? = nil
        var asyncHandler: ((Request, Response) -> Void)? = nil
    }

    private var rootNode = Node()

    func routes() -> [String] {
        var routes = [String]()
        for (_, child) in rootNode.nodes {
            routes.appendContentsOf(routesForNode(child));
        }
        return routes
    }

    private func routesForNode(node: Node, prefix: String = "") -> [String] {
        var result = [String]()
        if node.syncHandler != nil {
            result.append(prefix)
        }
        for (key, child) in node.nodes {
            result.appendContentsOf(routesForNode(child, prefix: prefix + "/" + key));
        }
        return result
    }

    func register(method: String?, path: String, syncHandler: (Request -> Response)?) {
        var pathSegments = stripQuery(path).split("/")
        if let method = method {
            pathSegments.insert(method, atIndex: 0)
        } else {
            pathSegments.insert("*", atIndex: 0)
        }
        var pathSegmentsGenerator = pathSegments.generate()
        inflate(&rootNode, generator: &pathSegmentsGenerator).syncHandler = syncHandler
    }

    func register(method: String?, path: String, asyncHandler: ((Request, Response) -> Void)?) {
        var pathSegments = stripQuery(path).split("/")
        if let method = method {
            pathSegments.insert(method, atIndex: 0)
        } else {
            pathSegments.insert("*", atIndex: 0)
        }
        var pathSegmentsGenerator = pathSegments.generate()
        inflate(&rootNode, generator: &pathSegmentsGenerator).asyncHandler = asyncHandler
    }

    func route(method: Request.Method?, path: String) -> (Request -> Response)? {
        if let method = method {
            let pathSegments = (method.rawValue + "/" + stripQuery(path)).split("/")
            var pathSegmentsGenerator = pathSegments.generate()
            var params = [String:String]()
            if let handler = findHandler(&rootNode, params: &params, generator: &pathSegmentsGenerator) {
                return handler
            }
        }
        let pathSegments = ("*/" + stripQuery(path)).split("/")
        var pathSegmentsGenerator = pathSegments.generate()
        var params = [String:String]()
        if let handler = findHandler(&rootNode, params: &params, generator: &pathSegmentsGenerator) {
            return handler
        }
        return nil
    }

    private func inflate(inout node: Node, inout generator: IndexingGenerator<[String]>) -> Node {
        if let pathSegment = generator.next() {
            if let _ = node.nodes[pathSegment] {
                return inflate(&node.nodes[pathSegment]!, generator: &generator)
            }
            var nextNode = Node()
            node.nodes[pathSegment] = nextNode
            return inflate(&nextNode, generator: &generator)
        }
        return node
    }

    private func findHandler(inout node: Node, inout params: [String: String], inout generator: IndexingGenerator<[String]>) -> (Request -> Response)? {
        guard let pathToken = generator.next() else {
            return node.syncHandler
        }
        let variableNodes = node.nodes.filter { $0.0.characters.first == ":" }
        if let variableNode = variableNodes.first {
            params[variableNode.0] = pathToken
            return findHandler(&node.nodes[variableNode.0]!, params: &params, generator: &generator)
        }
        if let _ = node.nodes[pathToken] {
            return findHandler(&node.nodes[pathToken]!, params: &params, generator: &generator)
        }
        if let _ = node.nodes["*"] {
            return findHandler(&node.nodes["*"]!, params: &params, generator: &generator)
        }
        return nil
    }

    private func stripQuery(path: String) -> String {
        if let path = path.split("?").first {
            return path
        }
        return path
    }
}
