//
//  AdvertController.swift
//  AdvertServer
//
//  Created by GlebRadchenko on 11/24/16.
//
//

import Foundation
import Vapor
import Auth
import Cookies
import HTTP

class AdvertController: DropConfigurable {
    weak var drop: Droplet?
    required init(with drop: Droplet) {
        self.drop = drop
    }
    func setup() {
        guard drop != nil else {
            return
        }
        addAdvertProvider()
        addRoutes()
    }
    private func addAdvertProvider() {
        guard let drop = drop else {
            return
        }
        drop.preparations.append(Advertisment.self)
    }
    private func addRoutes() {
        guard let drop = drop else {
            debugPrint("Drop is nil")
            return
        }
        let advertGroup = drop.grouped("advertisments")
        let authMiddleware = UserAuthorizedMiddleware()
        let tokenGroup = advertGroup.grouped(authMiddleware)
        
        tokenGroup.get(handler: advertInfo)
        tokenGroup.post(handler: create)
        tokenGroup.put(handler: edit)
        tokenGroup.delete(handler: delete)
    }
    func advertInfo(_ req: Request) throws -> ResponseRepresentable {
        guard let beaconId = req.data["beacon_id"] as? String else {
            throw Abort.custom(status: .badRequest, message: "No beacon_id")
        }
        //receive user with creds
        if let user = try req.auth.user() as? User {
            do {
                guard let beacon = try user.beacons()
                    .filter("id", contains: beaconId)
                    .first() else {
                        throw Abort.notFound
                }
                let advertNodes = try beacon.advertisments()
                    .all()
                    .map() { (advertisment) -> Node in
                        return try advertisment.makeNode()
                }
                let json = try JSON(node: advertNodes)
                return json
            } catch {
                throw Abort.custom(status: .badRequest, message: error.localizedDescription)
            }
        }
        throw Abort.custom(status: .badRequest, message: "Invalid credentials")
    }
    func create(_ req: Request) throws -> ResponseRepresentable {
        guard let title = req.data["title"]?.string,
            let description = req.data["description"]?.string,
            let parentId = req.data["beacon_id"]?.string else {
                throw Abort.custom(status: .badRequest, message: "Wrong parameters")
        }
        do {
            let user = try req.auth.user() as? User
            if let beacon = try  Beacon.find(parentId) {
                if try beacon.owner().get()?.id == user?.id {
                    var newAdvertisment = Advertisment(title: title, description: description)
                    newAdvertisment.parentId = beacon.id
                    if let media = req.data["media"] as? String {
                        newAdvertisment.media = media
                    }
                    try newAdvertisment.save()
                    return try JSON(node: [["error": false,
                                            "message": "Created"],
                                           try newAdvertisment.makeNode()] )
                } else {
                    throw Abort.custom(status: .badRequest, message: "Invalid beacon_id")
                }
            } else {
                throw Abort.notFound
            }
        } catch {
            throw Abort.custom(status: .badRequest, message: error.localizedDescription)
        }
    }
    func edit(_ req: Request) throws -> ResponseRepresentable {
        guard let id = req.data["id"] as? String else {
            throw Abort.custom(status: .badRequest, message: "Wrong parameters")
        }
        do {
            if let user = try req.auth.user() as? User {
                guard var advertToEdit = try Advertisment.find(id) else {
                    throw Abort.notFound
                }
                
                let parentBeacon = try advertToEdit.beacon().get()
                if try user.beacons()
                    .all()
                    .contains(where: { (beacon) -> Bool in
                        return beacon.id == parentBeacon?.id
                    }) {
                    if let title = req.data["title"] as? String {
                        advertToEdit.title = title
                    }
                    if let desc = req.data["description"] as? String {
                        advertToEdit.description = desc
                    }
                    if let media = req.data["media"] as? String {
                        advertToEdit.media = media
                    }
                    try advertToEdit.save()
                    return try JSON(node: ["error": false,
                                           "advertisment": try advertToEdit.makeNode()])
                } else {
                    throw Abort.custom(status: .notFound, message: "Such advertisment with such beacon not found")
                }
            } else {
                throw Abort.custom(status: .notFound, message: "Cannot find such user")
            }
        } catch {
            throw Abort.custom(status: .notFound, message: error.localizedDescription)
        }
    }
    func delete(_ req: Request) throws -> ResponseRepresentable {
        guard let id = req.data["id"] as? String else {
            throw Abort.custom(status: .badRequest, message: "Wrong parameters")
        }
        do {
            if let user = try req.auth.user() as? User {
                guard let advertToDelete = try Advertisment.find(id) else {
                    throw Abort.notFound
                }
                
                let parentBeacon = try advertToDelete.beacon().get()
                if try user.beacons()
                    .all()
                    .contains(where: { (beacon) -> Bool in
                        return beacon.id == parentBeacon?.id
                    }) {
                    try advertToDelete.delete()
                    return try JSON(node: ["error": false,
                                           "message": "Deleting successed"])
                } else {
                    throw Abort.custom(status: .notFound, message: "Such advertisment with such beacon not found")
                }
            } else {
                throw Abort.custom(status: .notFound, message: "Cannot find such user")
            }
        } catch {
            throw Abort.custom(status: .notFound, message: error.localizedDescription)
        }
    }
}
