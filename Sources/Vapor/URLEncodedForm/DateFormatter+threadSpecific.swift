//
//  File.swift
//  
//
//  Created by Ravneet Singh on 3/29/20.
//

import NIO

fileprivate let sharedISO8601DateFormatter = ISO8601DateFormatter()

extension ISO8601DateFormatter {
    static var shared: ISO8601DateFormatter {
      sharedISO8601DateFormatter
    }
}
