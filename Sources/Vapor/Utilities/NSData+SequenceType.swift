//
// NSData+SequenceType.swift
// Vapor
//
// Created by Robert Thompson on 03/02/2016
//

import Foundation

extension NSData: SequenceType {
    public func generate() -> UnsafeBufferPointer<UInt8>.Generator {
        return UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(self.bytes), count: self.length).generate()
    }
}
