//
//  JsonParser.swift
//  AdvertServer
//
//  Created by Gleb Radchenko on 30.10.16.
//
//

import Foundation

class JsonParser {
    class func appInfo(from data: AnyObject?) {
        guard let data = data as? Data else {
            debugPrint("No data")
            return
        }
        do {
            let serializedData = try JSONSerialization.jsonObject(with: data,
                                                                  options: .mutableLeaves)
            print(serializedData)
        } catch {
            print(error)
        }
    }
}
