//
//  RequestManager.swift
//  AdvertServer
//
//  Created by Gleb Radchenko on 30.10.16.
//
//

import Foundation

class RequestManager {
    //for backend use
    func sendSynchronous(request: Requestable?, completion: (_ data: AnyObject?, _ error: Error?) -> ()) {
        guard let request = request?.request else {
            completion(nil, nil)
            return
        }
        var response: URLResponse?
        do {
            let data = try NSURLConnection.sendSynchronousRequest(request, returning: &response)
            completion(data as AnyObject?, nil)
        } catch {
            completion(nil, error)
        }
    }
    //for client probable use
    func sendAsynchronous(request: Requestable?, completion: @escaping (_ data: AnyObject?, _ error: Error?) -> ()) {
        guard let request = request?.request else {
            completion(nil, nil)
            return
        }
        let task = URLSession
            .shared
            .dataTask(with: request) { (data, response, error) in
                completion(data as AnyObject?, error)
        }
        task.resume()
    }
}
protocol Requestable {
    var request: URLRequest? {get}
}
enum ApplicationAction: Requestable {
    static let url = "https://itunes.apple.com/lookup"
    case fullInfo(id: String)
    
    var httpMethod: String {
        switch self {
        case .fullInfo:
            return HTTPMethod.get.rawValue
        }
    }
    var additionalParameters: String {
        switch self {
        case let .fullInfo(id):
            return "?id=" + id
        }
    }
    var request: URLRequest? {
        switch self {
        case .fullInfo:
            guard let url = URL(string: ApplicationAction.url + self.additionalParameters) else {
                return nil
            }
            var request = URLRequest(url: url,
                                     cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                     timeoutInterval: 5.0)
            request.httpMethod = self.httpMethod
            return request
        }
    }
}
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

