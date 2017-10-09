import Foundation

final class HuffmanDecoder {
    let tree: HuffmanTree
    
    init(tree: HuffmanTree) {
        self.tree = tree
    }
    
    public func decode(data input: Data) -> Data {
        var output = Data()
        output.reserveCapacity(input.count)
        var currentTree = tree
        
        for byte in input {
            for bitOffset in 0..<8 {
                let goLeft = (byte << bitOffset) & 0b10000000 == 0
                
                let node = goLeft ? currentTree.left : currentTree.right
                
                switch node {
                case .single(let byte):
                    output.append(byte)
                    currentTree = self.tree
                case .many(let data):
                    output.append(contentsOf: data)
                    currentTree = self.tree
                case .tree(let tree):
                    currentTree = tree
                }
            }
        }
        
        return output
    }
}
