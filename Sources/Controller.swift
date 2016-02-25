//
//  Controller.swift
//  Vapor
//
//  Created by James Richard on 2/24/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

public protocol Controller: class {
    var request: Request { get }
    init(request: Request) throws
}
