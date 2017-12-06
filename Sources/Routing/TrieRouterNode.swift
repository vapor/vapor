import Foundation
import Bits

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
    case parameter([UInt8])
    case constant([UInt8])
}

extension TrieRouterNode {
    /// Finds the node with the supplied path in the
    /// node's constant children.
    func findNode(withConstant path: ByteBuffer) -> TrieRouterNode<Output>? {
        guard let pointer = path.baseAddress else {
            return nil
        }
        
        for child in children {
            guard case .constant(let constant) = child.kind else {
                continue
            }

            guard path.count == constant.count else {
                continue
            }

            if memcmp(pointer, constant, path.count) == 0 {
                return child
            }
        }

        return nil
    }

    /// Finds the node with the supplied path in the
    /// node's constant children.
    func findNode(withParameter path: ByteBuffer) -> (TrieRouterNode<Output>, [UInt8])? {
        guard let pointer = path.baseAddress else {
            return nil
        }
        
        for child in children {
            guard case .parameter(let parameter) = child.kind else {
                continue
            }

            guard path.count == parameter.count else {
                continue
            }

            if memcmp(pointer, parameter, path.count) == 0 {
                return (child, parameter)
            }
        }

        return nil
    }

    /// Returns the first parameter node
    func firstParameterNode() -> (TrieRouterNode<Output>, [UInt8])? {
        for child in children {
            guard case .parameter(let parameter) = child.kind else {
                continue
            }
            return (child, parameter)
        }

        return nil
    }
}

