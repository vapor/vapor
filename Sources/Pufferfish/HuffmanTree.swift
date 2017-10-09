import Foundation

public indirect enum HuffmanNode {
    case leaf(HuffmanAssociatedData)
    case tree(HuffmanTree)
}

struct InvalidEncodingTable: Swift.Error {}

public final class HuffmanTree {
    public var left: HuffmanNode
    public var right: HuffmanNode
    
    public init(left: HuffmanNode, right: HuffmanNode) {
        self.left = left
        self.right = right
    }
    
    public var encodingTable: EncodingTable {
        var table = EncodingTable()
        
        func process(_ node: HuffmanNode, encoded: UInt64 = 0, bits: UInt64 = 0) {
            switch node {
            case .tree(let tree):
                let shifted = encoded << 1
                
                process(tree.left, encoded: shifted, bits: bits &+ 1)
                process(tree.right, encoded: shifted  &+ 1, bits: bits &+ 1)
            case .leaf(let leaf):
                table.elements.append(leaf)
                table.encoded.append((encoded, UInt8(bits &+ 1)))
            }
        }
        
        process(self.left)
        process(self.right, encoded: 1)
        
        return table
    }
    
    public convenience init(encoded table: EncodingTable) throws {
        self.init(left: .leaf(.single(0)), right: .leaf(.single(0)))
        
        nextElement: for index in 0..<table.encoded.count {
            let (data, size) = table.encoded[index]
            var currentTree = self
            
            for bit in (0..<size).reversed() {
                let left =  (1 << bit) & data == 0
                
                // branch
                if bit == 0 {
                    let leaf = table.elements[index]
                    
                    if left {
                        currentTree.left = .leaf(leaf)
                    } else {
                        currentTree.right = .leaf(leaf)
                    }
                    
                    continue nextElement
                } else {
                    let node = left ? currentTree.left : currentTree.right
                    
                    if case .tree(let tree) = node {
                        currentTree = tree
                    } else {
                        let tree = HuffmanTree(left: .leaf(.single(0)), right: .leaf(.single(0)))
                        
                        if left {
                            currentTree.left = .tree(tree)
                        } else {
                            currentTree.right = .tree(tree)
                        }
                        
                        currentTree = tree
                    }
                }
            }
        }
    }
}
