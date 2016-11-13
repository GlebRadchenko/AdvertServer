//
//  Beacon.swift
//  AdvertServer
//
//  Created by Gleb Radchenko on 13.11.16.
//
//

import Foundation
import Vapor
import Fluent

final class Beacon: Model {
    var id: Node?
    var udid: String
    var major: String
    var minor: String
    var parent: User?
    
    var exists: Bool = false
    
    init(udid: String, major: String, minor: String) {
        self.udid = udid
        self.major = major
        self.minor = minor
    }
    
    init(node: Node, in context: Context) throws {
        id = try node.extract("id")
        udid = try node.extract("udid")
        major = try node.extract("major")
        minor = try node.extract("minor")
        parent = try node.extract("parent")
    }
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "_id": id,
            "udid": udid,
            "major": major,
            "minor": minor,
            "parent": parent
            ])
    }
    static func prepare(_ database: Database) throws {
        try database.create("beacons") { beacons in
            beacons.id()
            beacons.string("udid")
            beacons.string("major")
            beacons.string("minor")
            beacons.parent(User.self, optional: false)
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete("beacons")
    }
}
extension Beacon {
    func owner() throws -> Parent<User> {
        return try parent(parent?.id)
    }
}
