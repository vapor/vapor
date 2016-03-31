//
//  SHA2.swift
//  CryptoSwift
//
//  Created by Marcin Krzyzanowski on 24/08/14.
//  Copyright (c) 2014 Marcin Krzyzanowski. All rights reserved.
//

import libc

private func CS_AnyGenerator<Element>(body: () -> Element?) -> AnyIterator<Element> {
    return AnyIterator(body: body)
}

struct BytesSequence: Sequence {
    let chunkSize: Int
    let data: [UInt8]


    func makeIterator() -> AnyIterator<ArraySlice<UInt8>> {

        var offset: Int = 0

        return CS_AnyGenerator {
            let two = self.data.count - offset
            let end = Swift.min(self.chunkSize, two)
            let result = self.data[offset..<offset + end]
            offset += result.count
            return result.count > 0 ? result : nil
        }
    }
}

class SHA2 {
    init() {

    }

    func prepare(len: Int) -> Array<UInt8> {
        var tmpMessage = message

        // Step 1. Append Padding Bits
        tmpMessage.append(0x80) // append one bit (UInt8 with one bit) to message

        // append "0" bit until message length in bits ≡ 448 (mod 512)
        var msgLength = tmpMessage.count
        var counter = 0

        while msgLength % len != (len - 8) {
            counter += 1
            msgLength += 1
        }

        tmpMessage += Array<UInt8>(repeating: 0, count: counter)
        return tmpMessage
    }

    var size = 256

    var message: [UInt8] = []

    private var h: [UInt64] {
        return [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
    }

    private var k: [UInt64] {
        return [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
                    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
                    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
                    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
                    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
                    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
                    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
                    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ]
    }

    private func resultingArray<T>(hh: [T]) -> ArraySlice<T> {
        return ArraySlice(hh)
    }

    func calculate32() -> [UInt8] {
        var tmpMessage = self.prepare(64)

        // hash values
        var hh = [UInt32]()
        self.h.forEach {(h) -> () in
            hh.append(UInt32(h))
        }

        // append message length, in a 64-bit big-endian integer. So now the message length is a multiple of 512 bits.
        tmpMessage += (message.count * 8).bytes(64 / 8)

        // Process the message in successive 512-bit chunks:
        let chunkSizeBytes = 512 / 8 // 64
        for chunk in BytesSequence(chunkSize: chunkSizeBytes, data: tmpMessage) {
            // break chunk into sixteen 32-bit words M[j], 0 ≤ j ≤ 15, big-endian
            // Extend the sixteen 32-bit words into sixty-four 32-bit words:
            var M: [UInt32] = [UInt32](repeating: 0, count: self.k.count)
            for x in 0..<M.count {
                switch (x) {
                case 0...15:
                    let start = chunk.startIndex + (x * sizeofValue(M[x]))
                    let end = start + sizeofValue(M[x])
                    let le = toUInt32Array(chunk[start..<end])[0]
                    M[x] = le.bigEndian
                    break
                default:
                    let s0 = rotateRight(M[x-15], n: 7) ^ rotateRight(M[x-15], n: 18) ^ (M[x-15] >> 3)
                    let s1 = rotateRight(M[x-2], n: 17) ^ rotateRight(M[x-2], n: 19) ^ (M[x-2] >> 10)
                    M[x] = M[x-16] &+ s0 &+ M[x-7] &+ s1
                    break
                }
            }

            var A = hh[0]
            var B = hh[1]
            var C = hh[2]
            var D = hh[3]
            var E = hh[4]
            var F = hh[5]
            var G = hh[6]
            var H = hh[7]

            // Main loop
            for j in 0..<self.k.count {
                let s0 = rotateRight(A, n: 2) ^ rotateRight(A, n: 13) ^ rotateRight(A, n: 22)
                let maj = (A & B) ^ (A & C) ^ (B & C)
                let t2 = s0 &+ maj
                let s1 = rotateRight(E, n: 6) ^ rotateRight(E, n: 11) ^ rotateRight(E, n: 25)
                let ch = (E & F) ^ ((~E) & G)
                let t1 = H &+ s1 &+ ch &+ UInt32(self.k[j]) &+ M[j]

                H = G
                G = F
                F = E
                E = D &+ t1
                D = C
                C = B
                B = A
                A = t1 &+ t2
            }

            hh[0] = (hh[0] &+ A)
            hh[1] = (hh[1] &+ B)
            hh[2] = (hh[2] &+ C)
            hh[3] = (hh[3] &+ D)
            hh[4] = (hh[4] &+ E)
            hh[5] = (hh[5] &+ F)
            hh[6] = (hh[6] &+ G)
            hh[7] = (hh[7] &+ H)
        }

        // Produce the final hash value (big-endian) as a 160 bit number:
        var result = [UInt8]()
        result.reserveCapacity(hh.count / 4)

        self.resultingArray(hh).forEach {
            let item = $0.bigEndian
            result += [UInt8(item & 0xff)]
            result += [UInt8((item >> 8) & 0xff)]
            result += [UInt8((item >> 16) & 0xff)]
            result += [UInt8((item >> 24) & 0xff)]
        }
        return result
    }

}




/* array of bytes */
extension Int {
    /** Array of bytes with optional padding (little-endian) */
    func bytes(totalBytes: Int = sizeof(Int)) -> [UInt8] {
        return arrayOfBytes(self, length: totalBytes)
    }

    static func withBytes(bytes: ArraySlice<UInt8>) -> Int {
        return Int.withBytes(Array(bytes))
    }

    /** Int with array bytes (little-endian) */
    static func withBytes(bytes: [UInt8]) -> Int {
        return integerWithBytes(bytes)
    }
}





//
//  HMAC.swift
//  CryptoSwift
//
//  Created by Marcin Krzyzanowski on 13/01/15.
//  Copyright (c) 2015 Marcin Krzyzanowski. All rights reserved.
//


func toUInt32Array(slice: ArraySlice<UInt8>) -> Array<UInt32> {
    var result = Array<UInt32>()
    result.reserveCapacity(16)

    for idx in stride(from: slice.startIndex, to: slice.endIndex, by: sizeof(UInt32)) {
        let val1: UInt32 = (UInt32(slice[idx.advanced(by: 3)]) << 24)
        let val2: UInt32 = (UInt32(slice[idx.advanced(by: 2)]) << 16)
        let val3: UInt32 = (UInt32(slice[idx.advanced(by: 1)]) << 8)
        let val4: UInt32 = UInt32(slice[idx])
        let val: UInt32 = val1 | val2 | val3 | val4
        result.append(val)
    }
    return result
}




func rotateLeft(v: UInt8, _ n: UInt8) -> UInt8 {
    return ((v << n) & 0xFF) | (v >> (8 - n))
}

func rotateLeft(v: UInt16, _ n: UInt16) -> UInt16 {
    return ((v << n) & 0xFFFF) | (v >> (16 - n))
}

func rotateLeft(v: UInt32, _ n: UInt32) -> UInt32 {
    return ((v << n) & 0xFFFFFFFF) | (v >> (32 - n))
}

func rotateLeft(x: UInt64, _ n: UInt64) -> UInt64 {
    return (x << n) | (x >> (64 - n))
}

func rotateRight(x: UInt16, n: UInt16) -> UInt16 {
    return (x >> n) | (x << (16 - n))
}

func rotateRight(x: UInt32, n: UInt32) -> UInt32 {
    return (x >> n) | (x << (32 - n))
}

func rotateRight(x: UInt64, n: UInt64) -> UInt64 {
    return ((x >> n) | (x << (64 - n)))
}



/// Array of bytes, little-endian representation. Don't use if not necessary.
/// I found this method slow
func arrayOfBytes<T>(value: T, length: Int? = nil) -> [UInt8] {
    let totalBytes = length ?? sizeof(T)

    let valuePointer = UnsafeMutablePointer<T>(allocatingCapacity: 1)
    valuePointer.pointee = value

    let bytesPointer = UnsafeMutablePointer<UInt8>(valuePointer)
    var bytes = [UInt8](repeating: 0, count: totalBytes)
    for j in 0..<min(sizeof(T), totalBytes) {
        bytes[totalBytes - 1 - j] = (bytesPointer + j).pointee
    }

    valuePointer.deinitialize()
    valuePointer.deallocateCapacity(1)

    return bytes
}

/// Initialize integer from array of bytes.
/// This method may be slow
func integerWithBytes<T: Integer where T:ByteConvertible, T: BitshiftOperationsType>(bytes: [UInt8]) -> T {
    var bytes = bytes.reversed() as Array<UInt8>
    if bytes.count < sizeof(T) {
        let paddingCount = sizeof(T) - bytes.count
        if (paddingCount > 0) {
            bytes += [UInt8](repeating: 0, count: paddingCount)
        }
    }

    if sizeof(T) == 1 {
        return T(truncatingBitPattern: UInt64(bytes.first!))
    }

    var result: T = 0
    let reversed = bytes.reversed()
    for byte in reversed {
        result = result << 8 | T(byte)
    }
    return result
}

protocol BitshiftOperationsType {
    func <<(lhs: Self, rhs: Self) -> Self
    func >>(lhs: Self, rhs: Self) -> Self
    func <<=(lhs: inout Self, rhs: Self)
    func >>=(lhs: inout Self, rhs: Self)
}

protocol ByteConvertible {
    init(_ value: UInt8)
    init(truncatingBitPattern: UInt64)
}

extension Int    : BitshiftOperationsType, ByteConvertible { }
extension Int8   : BitshiftOperationsType, ByteConvertible { }
extension Int16  : BitshiftOperationsType, ByteConvertible { }
extension Int32  : BitshiftOperationsType, ByteConvertible { }
extension Int64  : BitshiftOperationsType, ByteConvertible {
    init(truncatingBitPattern value: UInt64) {
        self = Int64(bitPattern: value)
    }
}
extension UInt   : BitshiftOperationsType, ByteConvertible { }
extension UInt8  : BitshiftOperationsType, ByteConvertible { }
extension UInt16 : BitshiftOperationsType, ByteConvertible { }
extension UInt32 : BitshiftOperationsType, ByteConvertible { }
extension UInt64 : BitshiftOperationsType, ByteConvertible {
    init(truncatingBitPattern value: UInt64) {
        self = value
    }
}

/** build bit pattern from array of bits */

func integerFromBitsArray<T: UnsignedInteger>(bits: [Int]) -> T {
    var bitPattern: T = 0
    for (idx, b) in bits.enumerated() {
        if (b == 1) {
            let bit = T(UIntMax(1) << UIntMax(idx))
            bitPattern = bitPattern | bit
        }
    }
    return bitPattern
}

protocol CSArrayType: Sequence {
    func cs_arrayValue() -> [Iterator.Element]
}

extension Array: CSArrayType {
    func cs_arrayValue() -> [Iterator.Element] {
        return self
    }
}


extension CSArrayType where Iterator.Element == UInt8 {

    func toHexString() -> String {
        return self.lazy.reduce("") { previous, next in
            var converted = String(next, radix: 16)

            if converted.characters.count == 1 {
                converted = "0" + converted
            }

            return previous + converted
        }
    }
}

class HMAC {

    class func calculateHash(bytes bytes: [UInt8]) -> [UInt8]? {
        let sha = SHA2()
        sha.message = bytes
        return sha.calculate32()
    }

    class func authenticate(key  key: [UInt8], message: [UInt8]) -> [UInt8]? {
        var key = key


        if (key.count > 64) {
            if let hash = self.calculateHash(bytes: key) {
                key = hash
            }
        }

        if (key.count < 64) { // keys shorter than blocksize are zero-padded
            key = key + [UInt8](repeating: 0, count: 64 - key.count)
        }


        var opad = [UInt8](repeating: 0x5c, count: 64)
        for (idx, _) in key.enumerated() {
            opad[idx] = key[idx] ^ opad[idx]
        }
        var ipad = [UInt8](repeating: 0x36, count: 64)
        for (idx, _) in key.enumerated() {
            ipad[idx] = key[idx] ^ ipad[idx]
        }

        var finalHash: [UInt8]? = nil
        if let ipadAndMessageHash = self.calculateHash(bytes: ipad + message) {
            finalHash = self.calculateHash(bytes: opad + ipadAndMessageHash)
        }

        return finalHash
    }

}
