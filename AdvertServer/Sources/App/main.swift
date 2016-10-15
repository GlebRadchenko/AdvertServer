import Foundation
import Foundation
import Vapor
import VaporMongo
import Auth
import Cookies

let drop = Droplet()
let auth = AuthMiddleware(user: User.self) { value in
    return Cookie(
        name: "vapor-auth",
        value: value,
        expires: Date().addingTimeInterval(60 * 60 * 5), // 5 hours
        secure: true,
        httpOnly: true
    )
}
do {
    try drop.addProvider(VaporMongo.Provider.self)
} catch {
    print(error)
}
drop.preparations = [User.self]

drop.addConfigurable(middleware: auth, name: "auth")

drop.get { req in
    return try drop.view.make("welcome", [
    	"message": drop.localization[req.lang, "welcome", "title"]
    ])
}
drop.get("hello") { request in
    guard let name = request.data["name"]?.string else {
        throw Abort.badRequest
    }
    var user = User(name: name)
    do {
        try user.save()
         return "Hello, \(name)! you are saved"
    } catch {
        print(error)
        throw Abort.custom(status: .badRequest, message: "Your credentials was not saved")
    }
}
drop.run()
