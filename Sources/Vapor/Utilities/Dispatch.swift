//
//  After.swift
//
//  Created by Logan Wright on 10/24/15.
//  Copyright © 2015 lowriDevs. All rights reserved.
//

import Foundation

public typealias Block = () -> Void

public func Main(function: Block) {
    dispatch_async(dispatch_get_main_queue(), function)
}

public func Background(function: Block) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), function)
}

// **** Consider dependency, this is from Intrepid Swift Wisdom
// https://github.com/IntrepidPursuits/swift-wisdom/blob/master/SwiftWisdom/Core/Async/After/After.swift
