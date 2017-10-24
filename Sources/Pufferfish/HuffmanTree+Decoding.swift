import Foundation

public final class HuffmanDecoder {
    let tree: HuffmanTree
    
    public init(tree: HuffmanTree) {
        self.tree = tree
    }
    
    /// Deocdes huffman encoded data using the huffman tree
    public func decode(data input: Data) -> Data {
        var output = Data()
        output.reserveCapacity(input.count)
        var currentTree = tree
        
        // For each byte, walk down the tree
        for byte in input {
            // Go left or right depending on the bit
            for bitOffset in 0..<8 {
                let goLeft = (byte << bitOffset) & 0b10000000 == 0
                
                let node = goLeft ? currentTree.left : currentTree.right
                
                switch node {
                case .leaf(let leaf):
                    // If the next node is a leaf, write the contents to the output
                    // And reset the tree to the main tree
                    switch leaf {
                    case .single(let byte):
                        output.append(byte)
                        currentTree = self.tree
                    case .many(let data):
                        output.append(contentsOf: data)
                        currentTree = self.tree
                    }
                case .tree(let tree):
                    // if the next node is a tree, we haven't reached the end yet
                    currentTree = tree
                }
            }
        }
        
        return output
    }
}
