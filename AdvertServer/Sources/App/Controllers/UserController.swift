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
                guard let name = req.data["name"]?.string,
                let login = req.data["login"]?.string,
                let password = req.data["password"]?.string else {
                    throw Abort.badRequest
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
                if var user = try req.auth.user() as? User {
                    print("working with user")
                    print(user.token)
                    user.token = self.token(for: user)
                    let node = ["message": "Logged in", "access_token" : user.token]
                    return try JSON(node: node)
                }
                return try JSON(node: ["error": "invalid credentials"])
            }
            
            let protect = ProtectMiddleware(error:
                Abort.custom(status: .forbidden, message: "Not authorized.")
            )
            users.group(protect) { secure in
            }
//            users.group(protect) { secure in
//                secure.get("secure") { req in
//                    return try req.user()
//                }
//            }
        }
    }
    func token(for user: User) -> String {
        return encode(["hash":user.hash], algorithm: .hs256("secret".data(using: .utf8)!))
    }
}
