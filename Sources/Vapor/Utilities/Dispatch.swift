//
//  After.swift
//
//  Created by Logan Wright on 10/24/15.
//  Copyright © 2015 lowriDevs. All rights reserved.
//

import Strand

public typealias Block = () -> Void

public func Background(function: Block) throws {
    let _ = try Strand(closure: function)
}
