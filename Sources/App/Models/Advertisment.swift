//
//  Advertisment.swift
//  AdvertServer
//
//  Created by GlebRadchenko on 11/23/16.
//
//

import Foundation
import Vapor
import Fluent

final class Advertisment: Model {
    static let databaseName = "advertisments"
    
    var id: Node?
    var title: String
    var description: String
    var media: String?
    var parentId: Node?
    
    var exists: Bool = false
    
    init(title: String, description: String) {
        self.title = title
        self.description = description
    }
    
    init(node: Node, in context: Context) throws {
        id = try node.extract("id")
        title = try node.extract("title")
        description = try node.extract("description")
        media = try node.extract("media")
        parentId = try node.extract("parentId")
    }
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "_id": id,
            "title": title,
            "description": description,
            "media": media,
            "parentId": parentId
            ])
    }
    static func prepare(_ database: Database) throws {
        try database.create(self.databaseName) { advertisments in
            advertisments.id()
            advertisments.string("title")
            advertisments.string("description")
            advertisments.string("media", length: nil, optional: true)
            advertisments.id("parentId", optional: false)
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self.databaseName)
    }
}
extension Advertisment {
    func beacon() throws -> Parent<Beacon> {
        return try parent(parentId)
    }
}
