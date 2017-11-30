import Foundation

final class TrieRouterNode<Output> {
    /// Kind of node
    var kind: TrieRouterNodeKind

    /// All constant child nodes
    var children: [TrieRouterNode<Output>]

    /// This node's output
    var output: Output?

    init(
        kind: TrieRouterNodeKind,
        children: [TrieRouterNode<Output>] = [],
        output: Output? = nil
        ) {
        self.kind = kind
        self.children = children
        self.output = output
    }
}

enum TrieRouterNodeKind {
    case root
    case parameter(Data)
    case constant(Data)
}

extension TrieRouterNode {
    /// Finds the node with the supplied path in the
    /// node's constant children.
    func findNode(withConstant path: Data) -> TrieRouterNode<Output>? {
        for child in children {
            guard case .constant(let constant) = child.kind else {
                continue
            }

            guard path.count == constant.count else {
                continue
            }

            if path == constant {
                return child
            }
        }

        return nil
    }

    /// Finds the node with the supplied path in the
    /// node's constant children.
    func findNode(withParameter path: Data) -> (TrieRouterNode<Output>, Data)? {
        for child in children {
            guard case .parameter(let parameter) = child.kind else {
                continue
            }

            guard path.count == parameter.count else {
                continue
            }

            if path == parameter {
                return (child, parameter)
            }
        }

        return nil
    }
}

