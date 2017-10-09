import Foundation

indirect enum HuffmanNode {
    case value(UInt8)
    case tree(HuffmanTree)
}

struct HuffmanTree {
    let left: HuffmanNode
    let right: HuffmanNode
}

func +(lhs: HuffmanNode, rhs: HuffmanNode) -> HuffmanTree {
    return HuffmanTree(left: lhs, right: rhs)
}
