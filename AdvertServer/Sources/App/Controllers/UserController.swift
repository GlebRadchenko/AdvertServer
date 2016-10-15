//
//  UserController.swift
//  AdvertServer
//
//  Created by Gleb Radchenko on 15.10.16.
//
//

import Foundation
import Vapor
import Auth
import Cookies
import BCrypt

class UserController {
    weak var drop: Droplet?
    init(drop: Droplet) {
        debugPrint("initializing UserController")
        self.drop = drop
    }
    func setup() {
        guard drop != nil else {
            debugPrint("no droplet in usercontroller")
            return
        }
        addAuth()
        addUserProvider()
        addRoutes()
    }
    private func addAuth() {
        let auth = AuthMiddleware(user: User.self) { value in
            return Cookie(
                name: "vapor-auth",
                value: value,
                expires: Date().addingTimeInterval(60 * 60 * 5), // 5 hours
                secure: true,
                httpOnly: true
            )
        }
        drop?.addConfigurable(middleware: auth, name: "auth")
    }
    private func addUserProvider() {
        drop?.preparations = [User.self]
    }
    private func addRoutes() {
        guard let drop = drop else {
            debugPrint("Drop is nil")
            return
        }
        drop.group("users") { users in
            users.post { req in
                //register
                guard let name = req.data["name"]?.string,
                let login = req.data["login"]?.string,
                let password = req.data["password"]?.string else {
                    throw Abort.badRequest
                }
                if let _ = try User.query().filter("login", login).first() {
                    throw Abort.custom(status: .conflict, message: "Such user already exist")
                }
                var user = User(name: name, login: login, password: password)
                user.token = self.token(for: user)
                try user.save()
                return try user.makeJSON()
            }
            users.post("login") { req in
                guard let login = req.data["login"]?.string,
                let password = req.data["password"]?.string else {
                    throw Abort.badRequest
                }
                let creds = APIKey(id: login,
                                   secret: password)
                try req.auth.login(creds)
                guard let id = try req.auth.user().id,
                    let user = try User.find(id) else {
                    print("user not found")
                    throw Abort.badRequest
                }
                var newUser = User(user: user)
                newUser.token = self.token(for: user)
                try user.delete()
                try newUser.save()
                let node = ["message": "Logged in", "access_token" : newUser.token]
                return try JSON(node: node)
            }
            users.post("logout", handler: { (req) in
                guard let token = req.auth.header?.bearer else {
                    throw Abort.notFound
                }
                if let user = try User.query().filter("access_token", token.string).first() {
                    var newUser = User(user: user)
                    newUser.token = ""
                    try newUser.save()
                    try req.auth.logout()
                    return try JSON(node: ["error": false,
                                           "message": "Logout successed"])
                }
                throw Abort.badRequest
            })
        }
    }
    func token(for user: User) -> String {
        return encode(["hash":user.hash], algorithm: .hs256("secret".data(using: .utf8)!))
    }
}
