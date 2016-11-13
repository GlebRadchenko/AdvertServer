//
//  User.swift
//  AdvertServer
//
//  Created by Gleb Radchenko on 15.10.16.
//
//

import Foundation
import Vapor
import Fluent
import Auth
import BCrypt

final class User: Model {
    var id: Node?
    var name: String
    var login: String
    var hash: String
    var token: String = ""
    
    var exists: Bool = false
    
    init(name: String, login: String, password: String) {
        self.name = name
        self.login = login
        self.hash = BCrypt.hash(password: password)
    }
    
    init(node: Node, in context: Context) throws {
        id = try node.extract("_id")
        name = try node.extract("name")
        login = try node.extract("login")
        hash = try node.extract("hash")
        token = try node.extract("access_token")
    }
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "_id": id,
            "name": name,
            "login": login,
            "hash": hash,
            "access_token": token
            ])
    }
    static func prepare(_ database: Database) throws {
        try database.create("users") { users in
            users.id()
            users.string("name")
            users.string("login")
            users.string("hash")
            users.string("access_token")
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete("users")
    }
}
extension User {
    func beacons() throws -> Children<Beacon> {
        return children("parentId", Beacon.self)
    }
}

extension User: Auth.User {
    static func authenticate(credentials: Credentials) throws -> Auth.User {
        var user: User?
        
        switch credentials {
        case let id as Identifier:
            user = try User.find(id.id)
        case let accessToken as AccessToken:
            user = try User.query().filter("access_token", accessToken.string).first()
        case let apiKey as APIKey:
            do {
                if let tempUser = try User.query().filter("login", apiKey.id).first() {
                    if try BCrypt.verify(password: apiKey.secret, matchesHash: tempUser.hash) {
                        print("password matched")
                        user = tempUser
                    }
                }
            }
        default:
            throw Abort.custom(status: .badRequest, message: "Invalid credentials.")
        }
        
        guard let us = user else {
            throw Abort.custom(status: .badRequest, message: "User not found.")
        }
        return us
    }
    
    static func register(credentials: Credentials) throws -> Auth.User {
        throw Abort.custom(status: .badRequest, message: "Registration not supported")
    }
}
