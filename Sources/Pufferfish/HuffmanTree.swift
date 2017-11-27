import Foundation

// Huffman nodes exist of a splitting (left & right) or a leaf with data
indirect enum HuffmanNode {
    case leaf(HuffmanAssociatedData)
    case tree(HuffmanTree)
}

struct InvalidEncodingTable: Swift.Error {}

/// A huffman tree keeps track of byte(s) and their encoded form
///
/// Huffman trees can easily work backwards (decoding data)
public final class HuffmanTree {
    /// Left is walked when you hit a `0`
    var left: HuffmanNode
    
    /// Right is walked if you hit a `1`
    var right: HuffmanNode
    
    /// Creates a new huffmantree
    init(left: HuffmanNode, right: HuffmanNode) {
        self.left = left
        self.right = right
    }
    
    /// Generates an encoding table based on this huffman tree
    ///
    /// This requires a *real*, not manually invented/imaginary encoding table to work
    public var encodingTable: EncodingTable {
        var table = EncodingTable(reserving: 256)
        
        func process(_ node: HuffmanNode, encoded: UInt64 = 0, bits: UInt64 = 0) {
            switch node {
            case .tree(let tree):
                let shifted = encoded << 1
                
                process(tree.left, encoded: shifted, bits: bits &+ 1)
                process(tree.right, encoded: shifted &+ 1, bits: bits &+ 1)
            case .leaf(let leaf):
                table.elements.append(leaf)
                table.encoded.append((encoded, UInt8(bits &+ 1)))
            }
        }
        
        process(self.left)
        process(self.right, encoded: 1)
        
        return table
    }
    
    /// Creates a new huffman tree based on the encoding table
    public convenience init(encoded table: EncodingTable) throws {
        self.init(left: .leaf(.single(0)), right: .leaf(.single(0)))
        
        // Iterate over each encoded element
        nextElement: for index in 0..<table.encoded.count {
            let (data, size) = table.encoded[index]
            
            // Reset to the main tree
            var currentTree = self
            
            var bit = size
            
            // Walk down the tree for each bit
            while bit > 0 {
                bit = bit &- 1
                
                // Again, left is `0`, right is `1`
                let left = (1 << bit) & data == 0
                
                // branch off using the left or right
                // If this is the last bit, add a leaf
                if bit == 0 {
                    let leaf = table.elements[index]
                    
                    if case .single(let byte) = leaf, byte == 39 || byte == 42 {
//                        print(byte)
                    }
                    
                    if left {
                        currentTree.left = .leaf(leaf)
                    } else {
                        currentTree.right = .leaf(leaf)
                    }
                    
                    continue nextElement
                } else {
                    // If not at the leaf yet, create a new tree at this position (or re-use an existing tree)
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
