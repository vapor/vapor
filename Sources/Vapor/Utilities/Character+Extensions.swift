//
// Character+Extensions.swift
// Vapor
//
// Created by Logan Wright on 03/13/2016
//

// MARK: Character

// ASCII
// http://www.theasciicode.com.ar/ascii-control-characters/form-feed-female-symbol-venus-ascii-code-12.html
let NewLine: Byte = 10
let CarriageReturn: Byte = 13
let MinimumValidAsciiCharacter = CarriageReturn + 1

// MARK: Byte => Character

extension Character {
    init(_ byte: Byte) {
        let scalar = UnicodeScalar(byte)
        self.init(scalar)
    }
}