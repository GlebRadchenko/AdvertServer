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
import HTTP

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
        let userGroup = drop.grouped("users")
        userGroup.post(handler: register)
        userGroup.post("login", handler: login)
        
        let authMiddleware = UserAuthorizedMiddleware()
        let tokenGroup = userGroup.grouped(authMiddleware)
        tokenGroup.post("logout", handler: logout)
        tokenGroup.put(handler: edit)
        //TODO: Edit user, delete user
    }
    func register(_ req: Request) throws -> ResponseRepresentable {
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
    func edit(_ req: Request) throws -> ResponseRepresentable {
        if let user = try req.auth.user() as? User {
            var newUser = User(user: user)
            var isChanged = false
            if let newName = req.data["name"]?.string {
                newUser.name = newName
                isChanged = true
            }
            if let newLogin = req.data["login"]?.string {
                if (try User.query().filter("login", newLogin).first()) != nil {
                    throw Abort.custom(status: .badRequest, message: "Such login already exist")
                }
                newUser.login = newLogin
                isChanged = true
            }
            if isChanged {
                newUser.token = user.token
                try user.delete()
                try newUser.save()
                return try newUser.makeJSON()
            }
            throw Abort.custom(status: .badRequest, message: "No parameters")
        }
        throw Abort.custom(status: .badRequest, message: "Invalid credentials")
    }
//    func changePassword(_ req: Request) throws -> ResponseRepresentable {
//    }
    func login(_ req: Request) throws -> ResponseRepresentable {
        guard let login = req.data["login"]?.string,
            let password = req.data["password"]?.string else {
                throw Abort.badRequest
        }
        let creds = APIKey(id: login,
                           secret: password)
        try req.auth.login(creds)
        guard let id = try req.auth.user().id,
            let user = try User.find(id) else {
                throw Abort.notFound
        }
        var newUser = User(user: user)
        newUser.token = self.token(for: user)
        try user.delete()
        try newUser.save()
        let node = ["message": "Logged in", "access_token" : newUser.token]
        return try JSON(node: node)
    }
    func logout(_ req: Request) throws -> ResponseRepresentable {
        if var user = try req.auth.user() as? User {
            do {
                user.token = ""
                try user.save()
            } catch {
                print(error)
            }
            var newUser = User(user: user)
            newUser.token = ""
            do {
                try user.delete()
                try newUser.save()
                try req.auth.logout()
            } catch {
                print(error)
            }
            return try JSON(node: ["error": false,
                                   "message": "Logout successed"])
        }
        throw Abort.badRequest
    }
    func token(for user: User) -> String {
        let startDate = Date().toString()
        let endDate = Date().addingTimeInterval(24 * 60 * 60).toString()
        if let startDate = startDate, let endDate = endDate {
            return encode(["start": startDate,
                           "end": endDate], algorithm: .hs256(user.hash.data(using: .utf8)!))
        } else {
            debugPrint("wrong dates")
            return ""
        }
    }
}
extension Date {
    func toString() -> String? {
        let dateFormetter = DateFormatter()
        dateFormetter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormetter.calendar = Calendar(identifier: .gregorian)
        dateFormetter.dateFormat = "MM-dd-yyyy HH:mm"
        return dateFormetter.string(from: self)
    }
}
