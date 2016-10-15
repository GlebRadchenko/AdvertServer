import Vapor
import VaporMongo


let drop = Droplet()
//MARK: Adding MongoDB provider
do {
    try drop.addProvider(VaporMongo.Provider.self)
} catch {
    print(error)
}
drop.get { req in
    return try drop.view.make("welcome", [
    	"message": drop.localization[req.lang, "welcome", "title"]
    ])
}

//MARK: - Adding User routing
let userController = UserController(drop: drop)
userController.setup()

drop.run()
