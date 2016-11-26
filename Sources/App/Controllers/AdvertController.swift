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
        
        advertGroup.get(handler: advertInfo)
        advertGroup.get("all", handler: getAll)
        tokenGroup.post(handler: create)
        tokenGroup.put(handler: edit)
        tokenGroup.delete(handler: delete)
    }
    func getAll(_ req: Request) throws -> ResponseRepresentable {
        guard let beaconIdsString = req.data["beacons_id"]?.string else {
            throw Abort.custom(status: .badRequest, message: "No beacon_ids")
        }
        let arrayOfIds = beaconIdsString.components(separatedBy: ",")
        do {
            var arrayOfNodes = [Node]()
            var processedIds: [String] = []
            for beaconId in arrayOfIds {
                if processedIds.contains(beaconId) {
                    continue
                }
                do {
                    let atomaryNode = try advertismentNodes(for: beaconId)
                    arrayOfNodes.append(atomaryNode)
                    processedIds.append(beaconId)
                } catch {
                    print(error.localizedDescription)
                }
            }
            let arrayNode = Node.array(arrayOfNodes)
            return try JSON(node: arrayNode)
        } catch {
            throw Abort.custom(status: .badRequest, message: error.localizedDescription)
        }
    }
    func advertismentNodes(for beaconId: String) throws -> Node {
        guard let beacon = try Beacon.find(beaconId),
            let user = try beacon.owner().get() else {
                throw Abort.notFound
        }
        let advertNodes = try beacon.advertisments()
            .all()
            .map() { (advertisment) -> Node in
                return try advertisment.makeNode()
        }
        let ownerNode = Node.string(user.name)
        let responseNode = Node.object(["owner": ownerNode,
                                        "advertisments" : Node.array(advertNodes)])
        return responseNode
    }
    func advertInfo(_ req: Request) throws -> ResponseRepresentable {
        guard let beaconId = req.data["beacon_id"]?.string else {
            throw Abort.custom(status: .badRequest, message: "No beacon_id")
        }
        do {
            let responseNode = try advertismentNodes(for: beaconId)
            let json = try JSON(node: responseNode)
            return json
        } catch {
            throw Abort.custom(status: .badRequest, message: error.localizedDescription)
        }
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
