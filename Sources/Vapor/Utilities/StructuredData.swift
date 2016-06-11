//
//  StructuredData.swift
//  Vapor
//
//  Created by Tanner Nelson on 5/24/16.
//
//

import Foundation

extension StructuredData: PathIndexable {
    public var pathIndexableArray: [StructuredData]? {
        if case .array(let array) = self {
            return array
        } else {
            return nil
        }
    }

    public var pathIndexableObject: [String: StructuredData]? {
        if case .dictionary(let dict) = self {
            return dict
        } else {
            return nil
        }
    }

    public init(_ array: [StructuredData]) {
        self = .array(array)
    }

    public init(_ object: [String: StructuredData]) {
        self = .dictionary(object)
    }
}
