//
//  BeaconController.swift
//  AdvertServer
//
//  Created by Gleb Radchenko on 13.11.16.
//
//

import Foundation
import Vapor
import Auth
import Cookies
import HTTP

class BeaconController: DropConfigurable {
    weak var drop: Droplet?
    required init(with drop: Droplet) {
        self.drop = drop
    }
    func setup() {
        guard drop != nil else {
            return
        }
        addBeaconProvider()
        addRoutes()
    }
    private func addBeaconProvider() {
        guard let drop = drop else {
            return
        }
        drop.preparations.append(Beacon.self)
    }
    private func addRoutes() {
        guard let drop = drop else {
            debugPrint("Drop is nil")
            return
        }
        let beaconsGroup = drop.grouped("beacons")
        let authMiddleware = UserAuthorizedMiddleware()
        let tokenGroup = beaconsGroup.grouped(authMiddleware)
        
        tokenGroup.get(handler: beaconInfo)
        tokenGroup.post(handler: create)
        tokenGroup.put(handler: edit)
    }
    func beaconInfo(_ req: Request) throws -> ResponseRepresentable {
        //receive user with creds
        if let user = try req.auth.user() as? User {
            do {
                //this is not native method
                let beaconNodes = try user.beacons()
                    .map () { (beacon) in
                        return try beacon.makeNode()
                }
                let json = try JSON(node: beaconNodes)
                return json
            } catch {
                throw Abort.custom(status: .badRequest, message: error.localizedDescription)
            }
        }
        throw Abort.custom(status: .badRequest, message: "Invalid credentials")
    }
    func create(_ req: Request) throws -> ResponseRepresentable {
        guard let udid = req.data["udid"]?.string,
            let major = req.data["major"]?.string,
            let minor = req.data["minor"]?.string else {
                throw Abort.custom(status: .badRequest, message: "Wrong parameters")
        }
        do {
            var user = try req.auth.user()
            if try Beacon.query()
                .filter("udid", udid)
                .filter("major", major)
                .filter("minor", minor)
                .all().count != 0 {
                throw Abort.custom(status: .conflict, message: "Such beacon already exist")
            } else {
                var newBeacon = Beacon(udid: udid, major: major, minor: minor)
                newBeacon.parent = user as? User
                try newBeacon.save()
                try user.save()
                
                //this is for checking
                if let savedUser = try newBeacon.owner().get() {
                    print(savedUser.id == user.id)
                }
                //
                return try JSON(node: [["error": false,
                                        "message": "Created"],
                                       try newBeacon.makeNode()] )
            }
        } catch {
            throw Abort.custom(status: .badRequest, message: error.localizedDescription)
        }
    }
    func edit(_ req: Request) throws -> ResponseRepresentable {
        if var user = try req.auth.user() as? User {
            var isChanged = false
            if let newName = req.data["name"]?.string {
                user.name = newName
                isChanged = true
            }
            if let newLogin = req.data["login"]?.string {
                if (try User.query().filter("login", newLogin).first()) != nil {
                    throw Abort.custom(status: .badRequest, message: "Such login already exist")
                }
                user.login = newLogin
                isChanged = true
            }
            if isChanged {
                try user.save()
                return try user.makeJSON()
            }
            throw Abort.custom(status: .badRequest, message: "No parameters")
        }
        throw Abort.custom(status: .badRequest, message: "Invalid credentials")
    }
    func login(_ req: Request) throws -> ResponseRepresentable {
        guard let login = req.data["login"]?.string,
            let password = req.data["password"]?.string else {
                throw Abort.badRequest
        }
        let creds = APIKey(id: login,
                           secret: password)
        try req.auth.login(creds)
        guard let id = try req.auth.user().id,
            var user = try User.find(id) else {
                throw Abort.notFound
        }
        do {
            try user.save()
        } catch {
            print(error)
        }
        let node = ["message": "Logged in", "access_token" : user.token]
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
            do {
                
                try req.auth.logout()
            } catch {
                print(error)
            }
            return try JSON(node: ["error": false,
                                   "message": "Logout successed"])
        }
        throw Abort.badRequest
    }
}
