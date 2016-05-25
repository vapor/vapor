//
//  StructuredData.swift
//  Vapor
//
//  Created by Tanner Nelson on 5/24/16.
//
//

import Foundation

extension StructuredData {
    public subscript(index: Int) -> StructuredData? {
        switch self {
        case .array(let array):
            if array.count <= index {
                return nil
            }
            return array[index]
        case .dictionary(let dictionary):
            return dictionary["\(index)"]
        default:
            return nil
        }
    }

    public subscript(key: String) -> StructuredData? {
        switch self {
        case .array(let array):
            guard let index = Int(key) else {
                return nil
            }

            if array.count <= index {
                return nil
            }
            return array[index]
        case .dictionary(let dictionary):
            return dictionary[key]
        default:
            return nil
        }
    }
}

extension StructuredData: Polymorphic {
    public var isNull: Bool {
        if case .null = self {
            return true
        } else {
            return false
        }
    }

    public var bool: Bool? {
        if case .bool(let value) = self {
            return value
        } else {
            return nil
        }
    }

    public var float: Float? {
        if case .double(let double) = self {
            return Float(double)
        } else {
            return nil
        }
    }

    public var double: Double? {
        if case .double(let double) = self {
            return double
        } else {
            return nil
        }
    }

    public var int: Int? {
        if case .int(let int) = self {
            return int
        } else {
            return nil
        }
    }

    public var string: String? {
        if case .string(let string) = self {
            return string
        } else {
            return nil
        }
    }

    public var array: [Polymorphic]? {
        if case .array(let array) = self {
            return array.flatMap { $0 }
        } else {
            return nil
        }
    }

    public var object: [String : Polymorphic]? {
        if case .dictionary(let dict) = self {
            var object: [String: Polymorphic] = [:]

            dict.forEach { (key, value) in
                object[key] = value
            }

            return object
        } else {
            return nil
        }
    }
}
