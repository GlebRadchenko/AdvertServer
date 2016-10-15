//
//  User.swift
//  AdvertServer
//
//  Created by Gleb Radchenko on 15.10.16.
//
//

import Foundation
import Vapor
import Auth

final class User: Model {
    var id: Node?
    var name: String
    var exists: Bool = false
    
    init(name: String) {
        self.name = name
    }
    
    init(node: Node, in context: Context) throws {
        id = try node.extract("id")
        name = try node.extract("name")
    }
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id": id,
            "name": name
            ])
    }
    
    static func prepare(_ database: Database) throws {
        try database.create("users") { users in
            users.id()
            users.string("name")
            
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete("users")
    }
}
extension User: Auth.User {
    static func authenticate(credentials: Credentials) throws -> Auth.User {
        let user: User?
        
        switch credentials {
        case let id as Identifier:
            user = try User.find(id.id)
        case let accessToken as AccessToken:
            user = try User.query().filter("access_token", accessToken.string).first()
        case let apiKey as APIKey:
            user = try User.query().filter("email", apiKey.id).filter("password", apiKey.secret).first()
        default:
            throw Abort.custom(status: .badRequest, message: "Invalid credentials.")
        }
        
        guard let u = user else {
            throw Abort.custom(status: .badRequest, message: "User not found.")
        }
        
        return u
    }
    
    static func register(credentials: Credentials) throws -> Auth.User {
        throw Abort.custom(status: .badRequest, message: "Registration not supported")
    }
}
