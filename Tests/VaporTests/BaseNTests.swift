import Algorithms
import NIOCore
import Vapor
import XCTVapor
import XCTest

final class Base32Tests: XCTestCase {
    func testBase32() throws {
        // Base32 test vectors from [RFC 4648 § 10](https://datatracker.ietf.org/doc/html/rfc4648#section-10)
        XCTAssertEqual("".base32String(), "")
        XCTAssertEqual("f".base32String(), "MY======")
        XCTAssertEqual("fo".base32String(), "MZXQ====")
        XCTAssertEqual("foo".base32String(), "MZXW6===")
        XCTAssertEqual("foob".base32String(), "MZXW6YQ=")
        XCTAssertEqual("fooba".base32String(), "MZXW6YTB")
        XCTAssertEqual("foobar".base32String(), "MZXW6YTBOI======")

        XCTAssertEqual(Array(decodingBase32: "").map { String(decoding: $0, as: UTF8.self) }, "")
        XCTAssertEqual(Array(decodingBase32: "MY======").map { String(decoding: $0, as: UTF8.self) }, "f")
        XCTAssertEqual(Array(decodingBase32: "MZXQ====").map { String(decoding: $0, as: UTF8.self) }, "fo")
        XCTAssertEqual(Array(decodingBase32: "MZXW6===").map { String(decoding: $0, as: UTF8.self) }, "foo")
        XCTAssertEqual(Array(decodingBase32: "MZXW6YQ=").map { String(decoding: $0, as: UTF8.self) }, "foob")
        XCTAssertEqual(Array(decodingBase32: "MZXW6YTB").map { String(decoding: $0, as: UTF8.self) }, "fooba")
        XCTAssertEqual(Array(decodingBase32: "MZXW6YTBOI======").map { String(decoding: $0, as: UTF8.self) }, "foobar")

        let data = Data([1, 2, 3, 4])
        XCTAssertEqual(data.base32EncodedString(), "AEBAGBA")
        XCTAssertEqual(Data(base32Encoded: "AEBAGBA"), data)
        XCTAssertNil(Data(base32Encoded: data.base64EncodedString()))
    }
}

final class Base64Tests: XCTestCase {
    func testBase64() throws {
        // Base64 test vectors from [RFC 4648 § 10](https://datatracker.ietf.org/doc/html/rfc4648#section-10)
        XCTAssertEqual("".base64String(), "")
        XCTAssertEqual("f".base64String(), "Zg==")
        XCTAssertEqual("fo".base64String(), "Zm8=")
        XCTAssertEqual("foo".base64String(), "Zm9v")
        XCTAssertEqual("foob".base64String(), "Zm9vYg==")
        XCTAssertEqual("fooba".base64String(), "Zm9vYmE=")
        XCTAssertEqual("foobar".base64String(), "Zm9vYmFy")

        XCTAssertEqual(Array(decodingBase64: "").map { String(decoding: $0, as: UTF8.self) }, "")
        XCTAssertEqual(Array(decodingBase64: "Zg==").map { String(decoding: $0, as: UTF8.self) }, "f")
        XCTAssertEqual(Array(decodingBase64: "Zm8=").map { String(decoding: $0, as: UTF8.self) }, "fo")
        XCTAssertEqual(Array(decodingBase64: "Zm9v").map { String(decoding: $0, as: UTF8.self) }, "foo")
        XCTAssertEqual(Array(decodingBase64: "Zm9vYg==").map { String(decoding: $0, as: UTF8.self) }, "foob")
        XCTAssertEqual(Array(decodingBase64: "Zm9vYmE=").map { String(decoding: $0, as: UTF8.self) }, "fooba")
        XCTAssertEqual(Array(decodingBase64: "Zm9vYmFy").map { String(decoding: $0, as: UTF8.self) }, "foobar")
    }
}

final class BaseNTests: XCTestCase {
    /// This is six ASCII alphabetic characters, followed by one low and one high control character,
    /// followed by three codepoints in the high Latin-1 range (U+00A1 - U+00FF), then three in the
    /// range U+0100 - U+0FFF, four in the remainder of the BMP, three simple codepoints outside the
    /// BMP, a single-codepoint emoji, an emoji with variation selector, two multi-selector complex
    /// emoji, and finally, three flags chosen for their various encoding complexities.
    static let vector = "foobar\u{0009}\u{00a0}þàøƀāƿᏮᨡᡢꓞ𐌜𐍈𐔂😀👍🏼👩‍👩‍👧‍👧👨‍👨‍👦‍👦🏳️🏳️‍🌈🇺🇳"
    let checks = chain(chain(BaseNTests.vector.windows(ofCount: 1), BaseNTests.vector.windows(ofCount: 2)), [BaseNTests.vector[...]])

    func testBaseN() throws {
        // Set this to true to regenerate the "expected" test comparison vectors at the bottom of this file.
        let printVectors = false

        func check(with instance: BaseNEncoding, name: String, expected: [String], file: StaticString = #fileID, line: UInt = #line) {
            assert(self.checks.count == expected.count)

            XCTAssertEqual(instance.encode([]), [], file: (file), line: line)

            if printVectors { print("let expected\(name) = [", terminator: "") }
            for (elem, expected) in zip(self.checks, expected) {
                let encodedBytes = instance.encode(Array(elem.utf8))
                let encodedString = String(decoding: encodedBytes, as: Unicode.ASCII.self)
                let decodedBytes = instance.decode(encodedBytes)

                if printVectors {
                    print(
                        instance.bits > 6 ? "\(encodedBytes)" : "\"\(encodedString)\"",
                        terminator: elem.count == Self.vector.count ? "" : ", ")
                } else {
                    XCTAssertEqual(expected, encodedString, "string encode", file: (file), line: line)

                    XCTAssertEqual(Array(expected.utf8), encodedBytes, "byte encode", file: (file), line: line)
                    XCTAssertEqual(Array(elem.utf8), decodedBytes, "byte decode", file: (file), line: line)

                    let utf8ReadyBytes = decodedBytes.map { Array(chain($0.map(Int8.init(bitPattern:)), [0])) }
                    XCTAssertEqual(
                        utf8ReadyBytes.flatMap { String(validatingUTF8: $0)?[...] }, elem, "\(name) - \(elem) - \(decodedBytes ?? [])")
                }
            }
            if printVectors {
                print("]\(instance.bits > 6 ? ".map { String(decoding: $0, as: Unicode.ASCII.self) }" : "")")
            }
        }

        check(with: Base32.default, name: "Base32", expected: expectedBase32)
        check(with: Base32.lowercasedCanonical, name: "Base32Lower", expected: expectedBase32Lower)
        check(with: Base32.relaxed, name: "Base32Relaxed", expected: expectedBase32Relaxed)

        check(with: Base64.canonical, name: "Base64", expected: expectedBase64)
        check(with: Base64.bcrypt, name: "Base64Bcrypt", expected: expectedBase64Bcrypt)
    }
}

// Expected results for each series of permutations of the BaseN test input vector

let expectedHexLower = [
    "66", "6f", "6f", "62", "61", "72", "09", "c2a0", "c3be", "c3a0", "c3b8", "c680", "c481", "c6bf", "e18fae", "e1a8a1", "e1a1a2",
    "ea939e", "f0908c9c", "f0908d88", "f0909482", "f09f9880", "f09f918df09f8fbc", "f09f91a9e2808df09f91a9e2808df09f91a7e2808df09f91a7",
    "f09f91a8e2808df09f91a8e2808df09f91a6e2808df09f91a6", "f09f8fb3efb88f", "f09f8fb3efb88fe2808df09f8c88", "f09f87baf09f87b3", "666f",
    "6f6f", "6f62", "6261", "6172", "7209", "09c2a0", "c2a0c3be", "c3bec3a0", "c3a0c3b8", "c3b8c680", "c680c481", "c481c6bf", "c6bfe18fae",
    "e18faee1a8a1", "e1a8a1e1a1a2", "e1a1a2ea939e", "ea939ef0908c9c", "f0908c9cf0908d88", "f0908d88f0909482", "f0909482f09f9880",
    "f09f9880f09f918df09f8fbc", "f09f918df09f8fbcf09f91a9e2808df09f91a9e2808df09f91a7e2808df09f91a7",
    "f09f91a9e2808df09f91a9e2808df09f91a7e2808df09f91a7f09f91a8e2808df09f91a8e2808df09f91a6e2808df09f91a6",
    "f09f91a8e2808df09f91a8e2808df09f91a6e2808df09f91a6f09f8fb3efb88f", "f09f8fb3efb88ff09f8fb3efb88fe2808df09f8c88",
    "f09f8fb3efb88fe2808df09f8c88f09f87baf09f87b3",
    "666f6f62617209c2a0c3bec3a0c3b8c680c481c6bfe18faee1a8a1e1a1a2ea939ef0908c9cf0908d88f0909482f09f9880f09f918df09f8fbcf09f91a9e2808df09f91a9e2808df09f91a7e2808df09f91a7f09f91a8e2808df09f91a8e2808df09f91a6e2808df09f91a6f09f8fb3efb88ff09f8fb3efb88fe2808df09f8c88f09f87baf09f87b3",
]
let expectedHexUpper = [
    "66", "6F", "6F", "62", "61", "72", "09", "C2A0", "C3BE", "C3A0", "C3B8", "C680", "C481", "C6BF", "E18FAE", "E1A8A1", "E1A1A2",
    "EA939E", "F0908C9C", "F0908D88", "F0909482", "F09F9880", "F09F918DF09F8FBC", "F09F91A9E2808DF09F91A9E2808DF09F91A7E2808DF09F91A7",
    "F09F91A8E2808DF09F91A8E2808DF09F91A6E2808DF09F91A6", "F09F8FB3EFB88F", "F09F8FB3EFB88FE2808DF09F8C88", "F09F87BAF09F87B3", "666F",
    "6F6F", "6F62", "6261", "6172", "7209", "09C2A0", "C2A0C3BE", "C3BEC3A0", "C3A0C3B8", "C3B8C680", "C680C481", "C481C6BF", "C6BFE18FAE",
    "E18FAEE1A8A1", "E1A8A1E1A1A2", "E1A1A2EA939E", "EA939EF0908C9C", "F0908C9CF0908D88", "F0908D88F0909482", "F0909482F09F9880",
    "F09F9880F09F918DF09F8FBC", "F09F918DF09F8FBCF09F91A9E2808DF09F91A9E2808DF09F91A7E2808DF09F91A7",
    "F09F91A9E2808DF09F91A9E2808DF09F91A7E2808DF09F91A7F09F91A8E2808DF09F91A8E2808DF09F91A6E2808DF09F91A6",
    "F09F91A8E2808DF09F91A8E2808DF09F91A6E2808DF09F91A6F09F8FB3EFB88F", "F09F8FB3EFB88FF09F8FB3EFB88FE2808DF09F8C88",
    "F09F8FB3EFB88FE2808DF09F8C88F09F87BAF09F87B3",
    "666F6F62617209C2A0C3BEC3A0C3B8C680C481C6BFE18FAEE1A8A1E1A1A2EA939EF0908C9CF0908D88F0909482F09F9880F09F918DF09F8FBCF09F91A9E2808DF09F91A9E2808DF09F91A7E2808DF09F91A7F09F91A8E2808DF09F91A8E2808DF09F91A6E2808DF09F91A6F09F8FB3EFB88FF09F8FB3EFB88FE2808DF09F8C88F09F87BAF09F87B3",
]
let expectedBase32 = [
    "MY======", "N4======", "N4======", "MI======", "ME======", "OI======", "BE======", "YKQA====", "YO7A====", "YOQA====", "YO4A====",
    "Y2AA====", "YSAQ====", "Y27Q====", "4GH24===", "4GUKC===", "4GQ2E===", "5KJZ4===", "6CIIZHA=", "6CII3CA=", "6CIJJAQ=", "6CPZRAA=",
    "6CPZDDPQT6H3Y===", "6CPZDKPCQCG7BH4RVHRIBDPQT6I2PYUARXYJ7ENH", "6CPZDKHCQCG7BH4RVDRIBDPQT6I2NYUARXYJ7ENG", "6CPY7M7PXCHQ====",
    "6CPY7M7PXCH6FAEN6CPYZCA=", "6CPYPOXQT6D3G===", "MZXQ====", "N5XQ====", "N5RA====", "MJQQ====", "MFZA====", "OIEQ====", "BHBKA===",
    "YKQMHPQ=", "YO7MHIA=", "YOQMHOA=", "YO4MNAA=", "Y2AMJAI=", "YSA4NPY=", "Y276DD5O", "4GH25YNIUE======", "4GUKDYNBUI======",
    "4GQ2F2UTTY======", "5KJZ54EQRSOA====", "6CIIZHHQSCGYQ===", "6CII3CHQSCKIE===", "6CIJJAXQT6MIA===", "6CPZRAHQT6IY34E7R66A====",
    "6CPZDDPQT6H3Z4E7SGU6FAEN6CPZDKPCQCG7BH4RU7RIBDPQT6I2O===",
    "6CPZDKPCQCG7BH4RVHRIBDPQT6I2PYUARXYJ7ENH6CPZDKHCQCG7BH4RVDRIBDPQT6I2NYUARXYJ7ENG",
    "6CPZDKHCQCG7BH4RVDRIBDPQT6I2NYUARXYJ7ENG6CPY7M7PXCHQ====", "6CPY7M7PXCH7BH4PWPX3RD7CQCG7BH4MRA======",
    "6CPY7M7PXCH6FAEN6CPYZCHQT6D3V4E7Q6ZQ====",
    "MZXW6YTBOIE4FIGDX3B2BQ5YY2AMJAOGX7QY7LXBVCQ6DINC5KJZ54EQRSOPBEENRDYJBFEC6CPZRAHQT6IY34E7R66PBH4RVHRIBDPQT6I2TYUARXYJ7ENH4KAI34E7SGT7BH4RVDRIBDPQT6I2RYUARXYJ7ENG4KAI34E7SGTPBH4PWPX3RD7QT6H3H35YR7RIBDPQT6GIR4E7Q65PBH4HWM======",
]
let expectedBase32Lower = [
    "my======", "n4======", "n4======", "mi======", "me======", "oi======", "be======", "ykqa====", "yo7a====", "yoqa====", "yo4a====",
    "y2aa====", "ysaq====", "y27q====", "4gh24===", "4gukc===", "4gq2e===", "5kjz4===", "6ciizha=", "6cii3ca=", "6cijjaq=", "6cpzraa=",
    "6cpzddpqt6h3y===", "6cpzdkpcqcg7bh4rvhribdpqt6i2pyuarxyj7enh", "6cpzdkhcqcg7bh4rvdribdpqt6i2nyuarxyj7eng", "6cpy7m7pxchq====",
    "6cpy7m7pxch6faen6cpyzca=", "6cpypoxqt6d3g===", "mzxq====", "n5xq====", "n5ra====", "mjqq====", "mfza====", "oieq====", "bhbka===",
    "ykqmhpq=", "yo7mhia=", "yoqmhoa=", "yo4mnaa=", "y2amjai=", "ysa4npy=", "y276dd5o", "4gh25yniue======", "4gukdynbui======",
    "4gq2f2utty======", "5kjz54eqrsoa====", "6ciizhhqscgyq===", "6cii3chqsckie===", "6cijjaxqt6mia===", "6cpzrahqt6iy34e7r66a====",
    "6cpzddpqt6h3z4e7sgu6faen6cpzdkpcqcg7bh4ru7ribdpqt6i2o===",
    "6cpzdkpcqcg7bh4rvhribdpqt6i2pyuarxyj7enh6cpzdkhcqcg7bh4rvdribdpqt6i2nyuarxyj7eng",
    "6cpzdkhcqcg7bh4rvdribdpqt6i2nyuarxyj7eng6cpy7m7pxchq====", "6cpy7m7pxch7bh4pwpx3rd7cqcg7bh4mra======",
    "6cpy7m7pxch6faen6cpyzchqt6d3v4e7q6zq====",
    "mzxw6ytboie4figdx3b2bq5yy2amjaogx7qy7lxbvcq6dinc5kjz54eqrsopbeenrdyjbfec6cpzrahqt6iy34e7r66pbh4rvhribdpqt6i2tyuarxyj7enh4kai34e7sgt7bh4rvdribdpqt6i2ryuarxyj7eng4kai34e7sgtpbh4pwpx3rd7qt6h3h35yr7ribdpqt6gir4e7q65pbh4hwm======",
]
let expectedBase32Relaxed = [
    "MY", "N4", "N4", "MI", "ME", "OI", "BE", "YKQA", "YO7A", "YOQA", "YO4A", "Y2AA", "YSAQ", "Y27Q", "4GH24", "4GUKC", "4GQ2E", "5KJZ4",
    "6CIIZHA", "6CII3CA", "6CIJJAQ", "6CPZRAA", "6CPZDDPQT6H3Y", "6CPZDKPCQCG7BH4RVHRIBDPQT6I2PYUARXYJ7ENH",
    "6CPZDKHCQCG7BH4RVDRIBDPQT6I2NYUARXYJ7ENG", "6CPY7M7PXCHQ", "6CPY7M7PXCH6FAEN6CPYZCA", "6CPYPOXQT6D3G", "MZXQ", "N5XQ", "N5RA", "MJQQ",
    "MFZA", "OIEQ", "BHBKA", "YKQMHPQ", "YO7MHIA", "YOQMHOA", "YO4MNAA", "Y2AMJAI", "YSA4NPY", "Y276DD5O", "4GH25YNIUE", "4GUKDYNBUI",
    "4GQ2F2UTTY", "5KJZ54EQRSOA", "6CIIZHHQSCGYQ", "6CII3CHQSCKIE", "6CIJJAXQT6MIA", "6CPZRAHQT6IY34E7R66A",
    "6CPZDDPQT6H3Z4E7SGU6FAEN6CPZDKPCQCG7BH4RU7RIBDPQT6I2O",
    "6CPZDKPCQCG7BH4RVHRIBDPQT6I2PYUARXYJ7ENH6CPZDKHCQCG7BH4RVDRIBDPQT6I2NYUARXYJ7ENG",
    "6CPZDKHCQCG7BH4RVDRIBDPQT6I2NYUARXYJ7ENG6CPY7M7PXCHQ", "6CPY7M7PXCH7BH4PWPX3RD7CQCG7BH4MRA", "6CPY7M7PXCH6FAEN6CPYZCHQT6D3V4E7Q6ZQ",
    "MZXW6YTBOIE4FIGDX3B2BQ5YY2AMJAOGX7QY7LXBVCQ6DINC5KJZ54EQRSOPBEENRDYJBFEC6CPZRAHQT6IY34E7R66PBH4RVHRIBDPQT6I2TYUARXYJ7ENH4KAI34E7SGT7BH4RVDRIBDPQT6I2RYUARXYJ7ENG4KAI34E7SGTPBH4PWPX3RD7QT6H3H35YR7RIBDPQT6GIR4E7Q65PBH4HWM",
]
let expectedBase64 = [
    "Zg==", "bw==", "bw==", "Yg==", "YQ==", "cg==", "CQ==", "wqA=", "w74=", "w6A=", "w7g=", "xoA=", "xIE=", "xr8=", "4Y+u", "4aih", "4aGi",
    "6pOe", "8JCMnA==", "8JCNiA==", "8JCUgg==", "8J+YgA==", "8J+RjfCfj7w=", "8J+RqeKAjfCfkanigI3wn5Gn4oCN8J+Rpw==",
    "8J+RqOKAjfCfkajigI3wn5Gm4oCN8J+Rpg==", "8J+Ps++4jw==", "8J+Ps++4j+KAjfCfjIg=", "8J+HuvCfh7M=", "Zm8=", "b28=", "b2I=", "YmE=", "YXI=",
    "cgk=", "CcKg", "wqDDvg==", "w77DoA==", "w6DDuA==", "w7jGgA==", "xoDEgQ==", "xIHGvw==", "xr/hj64=", "4Y+u4aih", "4aih4aGi", "4aGi6pOe",
    "6pOe8JCMnA==", "8JCMnPCQjYg=", "8JCNiPCQlII=", "8JCUgvCfmIA=", "8J+YgPCfkY3wn4+8", "8J+RjfCfj7zwn5Gp4oCN8J+RqeKAjfCfkafigI3wn5Gn",
    "8J+RqeKAjfCfkanigI3wn5Gn4oCN8J+Rp/CfkajigI3wn5Go4oCN8J+RpuKAjfCfkaY=", "8J+RqOKAjfCfkajigI3wn5Gm4oCN8J+RpvCfj7PvuI8=",
    "8J+Ps++4j/Cfj7PvuI/igI3wn4yI", "8J+Ps++4j+KAjfCfjIjwn4e68J+Hsw==",
    "Zm9vYmFyCcKgw77DoMO4xoDEgca/4Y+u4aih4aGi6pOe8JCMnPCQjYjwkJSC8J+YgPCfkY3wn4+88J+RqeKAjfCfkanigI3wn5Gn4oCN8J+Rp/CfkajigI3wn5Go4oCN8J+RpuKAjfCfkabwn4+z77iP8J+Ps++4j+KAjfCfjIjwn4e68J+Hsw==",
]
let expectedBase64Bcrypt = [
    "Zg", "bw", "bw", "Yg", "YQ", "cg", "CQ", "wqA", "w74", "w6A", "w7g", "xoA", "xIE", "xr8", "4Y.u", "4aih", "4aGi", "6pOe", "8JCMnA",
    "8JCNiA", "8JCUgg", "8J.YgA", "8J.RjfCfj7w", "8J.RqeKAjfCfkanigI3wn5Gn4oCN8J.Rpw", "8J.RqOKAjfCfkajigI3wn5Gm4oCN8J.Rpg", "8J.Ps..4jw",
    "8J.Ps..4j.KAjfCfjIg", "8J.HuvCfh7M", "Zm8", "b28", "b2I", "YmE", "YXI", "cgk", "CcKg", "wqDDvg", "w77DoA", "w6DDuA", "w7jGgA",
    "xoDEgQ", "xIHGvw", "xr/hj64", "4Y.u4aih", "4aih4aGi", "4aGi6pOe", "6pOe8JCMnA", "8JCMnPCQjYg", "8JCNiPCQlII", "8JCUgvCfmIA",
    "8J.YgPCfkY3wn4.8", "8J.RjfCfj7zwn5Gp4oCN8J.RqeKAjfCfkafigI3wn5Gn",
    "8J.RqeKAjfCfkanigI3wn5Gn4oCN8J.Rp/CfkajigI3wn5Go4oCN8J.RpuKAjfCfkaY", "8J.RqOKAjfCfkajigI3wn5Gm4oCN8J.RpvCfj7PvuI8",
    "8J.Ps..4j/Cfj7PvuI/igI3wn4yI", "8J.Ps..4j.KAjfCfjIjwn4e68J.Hsw",
    "Zm9vYmFyCcKgw77DoMO4xoDEgca/4Y.u4aih4aGi6pOe8JCMnPCQjYjwkJSC8J.YgPCfkY3wn4.88J.RqeKAjfCfkanigI3wn5Gn4oCN8J.Rp/CfkajigI3wn5Go4oCN8J.RpuKAjfCfkabwn4.z77iP8J.Ps..4j.KAjfCfjIjwn4e68J.Hsw",
]
let expectedBase2 = [
    "01100110", "01101111", "01101111", "01100010", "01100001", "01110010", "00001001", "1100001010100000", "1100001110111110",
    "1100001110100000", "1100001110111000", "1100011010000000", "1100010010000001", "1100011010111111", "111000011000111110101110",
    "111000011010100010100001", "111000011010000110100010", "111010101001001110011110", "11110000100100001000110010011100",
    "11110000100100001000110110001000", "11110000100100001001010010000010", "11110000100111111001100010000000",
    "1111000010011111100100011000110111110000100111111000111110111100",
    "11110000100111111001000110101001111000101000000010001101111100001001111110010001101010011110001010000000100011011111000010011111100100011010011111100010100000001000110111110000100111111001000110100111",
    "11110000100111111001000110101000111000101000000010001101111100001001111110010001101010001110001010000000100011011111000010011111100100011010011011100010100000001000110111110000100111111001000110100110",
    "11110000100111111000111110110011111011111011100010001111",
    "1111000010011111100011111011001111101111101110001000111111100010100000001000110111110000100111111000110010001000",
    "1111000010011111100001111011101011110000100111111000011110110011", "0110011001101111", "0110111101101111", "0110111101100010",
    "0110001001100001", "0110000101110010", "0111001000001001", "000010011100001010100000", "11000010101000001100001110111110",
    "11000011101111101100001110100000", "11000011101000001100001110111000", "11000011101110001100011010000000",
    "11000110100000001100010010000001", "11000100100000011100011010111111", "1100011010111111111000011000111110101110",
    "111000011000111110101110111000011010100010100001", "111000011010100010100001111000011010000110100010",
    "111000011010000110100010111010101001001110011110", "11101010100100111001111011110000100100001000110010011100",
    "1111000010010000100011001001110011110000100100001000110110001000", "1111000010010000100011011000100011110000100100001001010010000010",
    "1111000010010000100101001000001011110000100111111001100010000000",
    "111100001001111110011000100000001111000010011111100100011000110111110000100111111000111110111100",
    "111100001001111110010001100011011111000010011111100011111011110011110000100111111001000110101001111000101000000010001101111100001001111110010001101010011110001010000000100011011111000010011111100100011010011111100010100000001000110111110000100111111001000110100111",
    "1111000010011111100100011010100111100010100000001000110111110000100111111001000110101001111000101000000010001101111100001001111110010001101001111110001010000000100011011111000010011111100100011010011111110000100111111001000110101000111000101000000010001101111100001001111110010001101010001110001010000000100011011111000010011111100100011010011011100010100000001000110111110000100111111001000110100110",
    "1111000010011111100100011010100011100010100000001000110111110000100111111001000110101000111000101000000010001101111100001001111110010001101001101110001010000000100011011111000010011111100100011010011011110000100111111000111110110011111011111011100010001111",
    "111100001001111110001111101100111110111110111000100011111111000010011111100011111011001111101111101110001000111111100010100000001000110111110000100111111000110010001000",
    "11110000100111111000111110110011111011111011100010001111111000101000000010001101111100001001111110001100100010001111000010011111100001111011101011110000100111111000011110110011",
    "01100110011011110110111101100010011000010111001000001001110000101010000011000011101111101100001110100000110000111011100011000110100000001100010010000001110001101011111111100001100011111010111011100001101010001010000111100001101000011010001011101010100100111001111011110000100100001000110010011100111100001001000010001101100010001111000010010000100101001000001011110000100111111001100010000000111100001001111110010001100011011111000010011111100011111011110011110000100111111001000110101001111000101000000010001101111100001001111110010001101010011110001010000000100011011111000010011111100100011010011111100010100000001000110111110000100111111001000110100111111100001001111110010001101010001110001010000000100011011111000010011111100100011010100011100010100000001000110111110000100111111001000110100110111000101000000010001101111100001001111110010001101001101111000010011111100011111011001111101111101110001000111111110000100111111000111110110011111011111011100010001111111000101000000010001101111100001001111110001100100010001111000010011111100001111011101011110000100111111000011110110011",
]
let expectedBase4 = [
    "1212", "1233", "1233", "1202", "1201", "1302", "0021", "30022200", "30032332", "30032200", "30032320", "30122000", "30102001",
    "30122333", "320120332232", "320122202201", "320122012202", "322221032132", "3300210020302130", "3300210020312020", "3300210021102002",
    "3300213321202000", "33002133210120313300213320332330",
    "3300213321012221320220002031330021332101222132022000203133002133210122133202200020313300213321012213",
    "3300213321012220320220002031330021332101222032022000203133002133210122123202200020313300213321012212", "3300213320332303323323202033",
    "33002133203323033233232020333202200020313300213320302020", "33002133201323223300213320132303", "12121233", "12331233", "12331202",
    "12021201", "12011302", "13020021", "002130022200", "3002220030032332", "3003233230032200", "3003220030032320", "3003232030122000",
    "3012200030102001", "3010200130122333", "30122333320120332232", "320120332232320122202201", "320122202201320122012202",
    "320122012202322221032132", "3222210321323300210020302130", "33002100203021303300210020312020", "33002100203120203300210021102002",
    "33002100211020023300213321202000", "330021332120200033002133210120313300213320332330",
    "330021332101203133002133203323303300213321012221320220002031330021332101222132022000203133002133210122133202200020313300213321012213",
    "33002133210122213202200020313300213321012221320220002031330021332101221332022000203133002133210122133300213321012220320220002031330021332101222032022000203133002133210122123202200020313300213321012212",
    "33002133210122203202200020313300213321012220320220002031330021332101221232022000203133002133210122123300213320332303323323202033",
    "330021332033230332332320203333002133203323033233232020333202200020313300213320302020",
    "3300213320332303323323202033320220002031330021332030202033002133201323223300213320132303",
    "1212123312331202120113020021300222003003233230032200300323203012200030102001301223333201203322323201222022013201220122023222210321323300210020302130330021002031202033002100211020023300213321202000330021332101203133002133203323303300213321012221320220002031330021332101222132022000203133002133210122133202200020313300213321012213330021332101222032022000203133002133210122203202200020313300213321012212320220002031330021332101221233002133203323033233232020333300213320332303323323202033320220002031330021332030202033002133201323223300213320132303",
]
let expectedBase8 = [
    "314", "336", "336", "304", "302", "344", "022", "605200", "607370", "607200", "607340", "615000", "611004", "615374", "70307656",
    "70324241", "70320642", "72511636", "74110214470", "74110215420", "74110224404", "74117630400", "7411762143370237437360",
    "7411762152361200433702374432474240106760477106477050021574117621516",
    "7411762152161200433702374432434240106760477106467050021574117621514", "7411761754767670436", "74117617547676704376120043370237431040",
    "7411760756570237417314", "314674", "336674", "336610", "304604", "302710", "344044", "02341240", "60520303574", "60737303500",
    "60720303560", "60734306400", "61500304402", "61100706576", "61537741437270", "7030765670324241", "7032424170320642",
    "7032064272511636", "7251163674110214470", "7411021447170220433040", "7411021542170220451010", "7411022440570237461000",
    "74117630401702374430676047707674", "7411762143370237437363604771065170500215741176215236120043370237443237424010676047710647",
    "74117621523612004337023744324742401067604771064770500215741176215177023744324342401067604771065070500215741176215156120043370237443230",
    "74117621521612004337023744324342401067604771064670500215741176215157023743731757561074",
    "74117617547676704377023743731757561077424010676047706210", "74117617547676704376120043370237431043604770367274117607546",
    "314675573046056202341240607373035014167061500304403432777030765670324241703206427251163674110214471702204330436044112202741176304017023744306760477076747411762152361200433702374432474240106760477106477050021574117621517702374432434240106760477106507050021574117621515612004337023744323360477076637373421774117617547676704376120043370237431043604770367274117607546",
]
let expectedBase128 = [
    [51, 0], [55, 64], [55, 64], [49, 0], [48, 64], [57, 0], [4, 64], [97, 40, 0], [97, 111, 64], [97, 104, 0], [97, 110, 0], [99, 32, 0],
    [98, 32, 32], [99, 47, 96], [112, 99, 117, 96], [112, 106, 20, 16], [112, 104, 52, 32], [117, 36, 115, 96], [120, 36, 17, 73, 96],
    [120, 36, 17, 88, 64], [120, 36, 18, 72, 16], [120, 39, 115, 8, 0], [120, 39, 114, 24, 111, 66, 63, 15, 94, 0],
    [120, 39, 114, 26, 79, 10, 1, 13, 120, 39, 114, 26, 79, 10, 1, 13, 120, 39, 114, 26, 63, 10, 1, 13, 120, 39, 114, 26, 56],
    [120, 39, 114, 26, 71, 10, 1, 13, 120, 39, 114, 26, 71, 10, 1, 13, 120, 39, 114, 26, 55, 10, 1, 13, 120, 39, 114, 26, 48],
    [120, 39, 113, 123, 31, 62, 113, 15], [120, 39, 113, 123, 31, 62, 113, 15, 113, 32, 17, 95, 4, 126, 25, 8],
    [120, 39, 112, 123, 87, 66, 63, 7, 89, 64], [51, 27, 96], [55, 91, 96], [55, 88, 64], [49, 24, 32], [48, 92, 64], [57, 2, 32],
    [4, 112, 84, 0], [97, 40, 24, 59, 112], [97, 111, 88, 58, 0], [97, 104, 24, 59, 64], [97, 110, 24, 104, 0], [99, 32, 24, 72, 8],
    [98, 32, 56, 107, 120], [99, 47, 124, 24, 125, 56], [112, 99, 117, 110, 13, 34, 66], [112, 106, 20, 30, 13, 6, 68],
    [112, 104, 52, 46, 84, 78, 60], [117, 36, 115, 111, 4, 66, 25, 28], [120, 36, 17, 73, 103, 66, 33, 13, 68, 0],
    [120, 36, 17, 88, 71, 66, 33, 20, 65, 0], [120, 36, 18, 72, 23, 66, 63, 24, 64, 0],
    [120, 39, 115, 8, 7, 66, 63, 17, 70, 124, 19, 120, 125, 112],
    [
        120, 39, 114, 24, 111, 66, 63, 15, 94, 60, 19, 121, 13, 39, 69, 0, 70, 124, 19, 121, 13, 39, 69, 0, 70, 124, 19, 121, 13, 31, 69, 0,
        70, 124, 19, 121, 13, 28,
    ],
    [
        120, 39, 114, 26, 79, 10, 1, 13, 120, 39, 114, 26, 79, 10, 1, 13, 120, 39, 114, 26, 63, 10, 1, 13, 120, 39, 114, 26, 63, 66, 63, 17,
        84, 56, 80, 8, 111, 66, 63, 17, 84, 56, 80, 8, 111, 66, 63, 17, 83, 56, 80, 8, 111, 66, 63, 17, 83, 0,
    ],
    [
        120, 39, 114, 26, 71, 10, 1, 13, 120, 39, 114, 26, 71, 10, 1, 13, 120, 39, 114, 26, 55, 10, 1, 13, 120, 39, 114, 26, 55, 66, 63, 15,
        89, 123, 119, 8, 120,
    ], [120, 39, 113, 123, 31, 62, 113, 15, 120, 39, 113, 123, 31, 62, 113, 15, 113, 32, 17, 95, 4, 126, 25, 8],
    [120, 39, 113, 123, 31, 62, 113, 15, 113, 32, 17, 95, 4, 126, 25, 8, 120, 39, 112, 123, 87, 66, 63, 7, 89, 64],
    [
        51, 27, 109, 118, 19, 5, 100, 9, 97, 40, 24, 59, 118, 14, 65, 67, 92, 49, 80, 12, 36, 7, 13, 63, 112, 99, 117, 110, 13, 34, 67, 97,
        80, 104, 93, 41, 28, 123, 97, 16, 70, 39, 30, 9, 4, 54, 17, 112, 72, 37, 16, 47, 4, 126, 49, 0, 120, 39, 114, 24, 111, 66, 63, 15,
        94, 60, 19, 121, 13, 39, 69, 0, 70, 124, 19, 121, 13, 39, 69, 0, 70, 124, 19, 121, 13, 31, 69, 0, 70, 124, 19, 121, 13, 31, 97, 31,
        72, 106, 28, 40, 4, 55, 97, 31, 72, 106, 28, 40, 4, 55, 97, 31, 72, 105, 92, 40, 4, 55, 97, 31, 72, 105, 94, 9, 124, 62, 103, 111,
        92, 35, 126, 9, 124, 62, 103, 111, 92, 35, 124, 40, 4, 55, 97, 31, 70, 34, 30, 9, 124, 30, 117, 112, 79, 97, 118, 48,
    ],
].map { String(decoding: $0, as: Unicode.ASCII.self) }

// #if !DEBUG
// #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
// extension XCTMeasureOptions { static var def: XCTMeasureOptions { BaseNPerformanceTests.defaultMeasureOptions } }
// #else
// typealias XCTMeasureOptions = Void; extension XCTMeasureOptions { static var def: XCTMeasureOptions { () } }
// #endif

// extension Array where Element == UInt8 { var asStr: String { .init(decoding: self, as: Unicode.ASCII.self) } }

// /// N.B.: All of this absurd repeating of test methods is unfortunately required due to XCTest not letting
// /// you measure more than one set of metrics per test case. I originally wrote this as a single test method
// /// which called `measure()` a bunch of times; it was MUCH shorter and perfectly readable, so of course
// /// XCTest refused to accept it.
// ///
// /// And by the way, could XCTest please figure out which freaking API is the right one to use for measuring
// /// things? There's metrics and performance metrics and measurement without any of that and Linux not supporting
// /// the "newer" "metrics" and there's just no way to make any sense of it.
// ///
// /// I truly, mind you **TRULY**, adore that `measure(_:)` ignores `defaultMetrics` in favor of
// /// `defaultPerformanceMetrics` and there's no way to change it, meaning every method has to waste more space
// /// specifying `options: .default` or `options: self.defaultMeasureOptions`, since the "modern" version of the
// /// API "uses symbolication" to decide where the Xcode UI for performance measurements should appear instead
// /// of allowing file/line info to be forwarded like the Linux version and any attempt to use a helper method
// /// to skip out on the highly problematic repetition renders the UI even utterly useless than it already is.
// /// I honestly can't think of a more perfect way to design an API so that no one will ever use it.
// final class BaseNPerformanceTests: XCTestCase {
//     private static let iterations = 524288
//     private static let encodeBuffer: Array<UInt8> = Array((.min ... .max).cycled(times: 32))
//     private static let encodeData: Data = Data(BaseNPerformanceTests.encodeBuffer)

//     #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
//     override public class var defaultMetrics: [XCTMetric] { [XCTClockMetric()] }
//     override public class var defaultMeasureOptions: XCTMeasureOptions {
//         let options = XCTMeasureOptions()
//         options.iterationCount = 5
//         return options
//     }
//     #else
//     private func measure(file: StaticString = #fileID, line: UInt = #line, options _: XCTMeasureOptions, block: () -> Void) {
//         self.measure(file: (file), line: line, block)
//     }
//     #endif

//     private func loop<R>(over block: () -> R) { for _ in 0..<Self.iterations { _ = block() } }

//     // Base32 via BaseN
//     func testBase32Encode_BytToByt()  { measure(options: .def) { self.loop { Base32.default.encode(BaseNPerformanceTests.encodeBuffer) } } }
//     func testBase32Decode_BytToByt()  { let buf = Base32.default.encode(Self.encodeBuffer); measure(options: .def) { self.loop { Base32.default.decode(buf) } } }

//     // Base64 via BaseN
//     func testBase64Encode_BytToByt() { measure(options: .def) { self.loop { Base64.default.encode(BaseNPerformanceTests.encodeBuffer) } } }
//     func testBase64Decode_BytToByt() { let buf = Base64.default.encode(Self.encodeBuffer); measure(options: .def) { self.loop { Base64.default.decode(buf) } } }

//     // Base64 via Foundation
//     func testBase64Encode_DatToDat()  { measure(options: .def) { self.loop { Self.encodeData.base64EncodedData() } } }
//     func testBase64Decode_DatToDat()  { let data = Self.encodeData.base64EncodedData(); measure(options: .def) { self.loop { Data(base64Encoded: data) } } }
// }
// #endif
