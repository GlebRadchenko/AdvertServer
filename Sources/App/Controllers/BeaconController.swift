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
        tokenGroup.delete(handler: delete)
    }
    func beaconInfo(_ req: Request) throws -> ResponseRepresentable {
        //receive user with creds
        if let user = try req.auth.user() as? User {
            do {
                let beaconNodes = try user.beacons()
                    .all()
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
                newBeacon.parentId = user.id
                try newBeacon.save()
                return try JSON(node: [["error": false,
                                        "message": "Created"],
                                       try newBeacon.makeNode()] )
            }
        } catch {
            throw Abort.custom(status: .badRequest, message: error.localizedDescription)
        }
    }
    func delete(_ req: Request) throws -> ResponseRepresentable {
        guard let id = req.data["id"] as? String else {
            throw Abort.custom(status: .badGateway, message: "Wrong parameters")
        }
        do {
            if let beacon = try Beacon.find(id) {
                try beacon.delete()
                return try JSON(node: ["error": false,
                                       "message": "Deleting successed"])
            } else {
                throw Abort.custom(status: .notFound, message: "Cannot find such beacon")
            }
        } catch {
            throw Abort.custom(status: .notFound, message: error.localizedDescription)
        }
    }
}
