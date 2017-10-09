import Foundation

indirect enum HuffmanNode {
    case single(UInt8)
    case many(Data)
    case tree(HuffmanTree)
}

struct InvalidEncodingTable: Swift.Error {}

final class HuffmanTree {
    var left: HuffmanNode
    var right: HuffmanNode
    
    init(left: HuffmanNode, right: HuffmanNode) {
        self.left = left
        self.right = right
    }
    
    convenience init(encoded table: EncodingTable) throws {
        self.init(left: .single(0), right: .single(0))
        
        nextElement: for index in 0..<table.encoded.count {
            let (data, size) = table.encoded[index]
            var currentTree = self
            
            for bit in (0..<size).reversed() {
                let left =  (1 << bit) & data == 0
                
                // branch
                if bit == 0 {
                    let byte = table.elements[index]
                    
                    if left {
                        currentTree.left = .single(byte)
                    } else {
                        currentTree.right = .single(byte)
                    }
                    
                    continue nextElement
                } else {
                    let node = left ? currentTree.left : currentTree.right
                    
                    if case .tree(let tree) = node {
                        currentTree = tree
                    } else {
                        let tree = HuffmanTree(left: .single(0), right: .single(0))
                        
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
        
        print(self)
    }
}

func +(lhs: HuffmanNode, rhs: HuffmanNode) -> HuffmanTree {
    return HuffmanTree(left: lhs, right: rhs)
}
