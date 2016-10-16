//
//  UserAuthorizedMiddleWare.swift
//  AdvertServer
//
//  Created by Gleb Radchenko on 16.10.16.
//
//

import Foundation
import Vapor
import HTTP

final class UserAuthorizedMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard let token = request.auth.header?.bearer else {
            throw Abort.custom(status: .badRequest, message: "Token is missing")
        }
        do {
            let user = try request.auth.user() as? User
            if user?.token != token.string {
                throw Abort.custom(status: .badRequest, message: "Invalid token")
            }
        } catch {
            do {
                try request.auth.login(token)
            } catch {
                throw Abort.custom(status: .badRequest, message: "Invalid token")
            }
        }
        return try next.respond(to: request)
    }
}
