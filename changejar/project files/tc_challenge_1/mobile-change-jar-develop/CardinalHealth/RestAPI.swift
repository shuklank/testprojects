//
//  RestAPI.swift
//  CardinalHealth
//
//  Created by Alexander Volkov on 07.04.15.
//  Modified by Volkov Alexander on 22.09.15.
//  Copyright (c) 2015 TopCoder. All rights reserved.
//

import Foundation
import Alamofire

/**
standard Http status code definitions
*/
public enum HttpStatusCode: Int {
    case OK = 200
    case Redirect = 300
    case ClientError = 400
    case ServerError = 500
}

/// common errors
let ERROR_UNAUTHORIZED = "Unauthorized access."
let ERROR_INVALID_EMAIL = "Invalid email"

/**
* Presents raw API methods to request RESTFul services.
* This class can be wrapped to provide a higher level API
*
* @author Alexander Volkov
* @version 1.1
*
* changes:
* 1.1:
* - Swift 2.0 support
*/
class RestAPI {
    
    /// Base URL for services
    private var baseUrl: String = ""
    
    /// the access token used for authorization
    var accessToken: String = ""
    
    /// the name of the authorization header
    let AUTH_HEADER = "Email"
    
    /**
    Creates new instance of RestAPI
    
    - parameter baseUrl:     API Base URL. Should be obtained from Configuration
    - parameter accessToken: the access token used for all HTTP requests.
    
    - returns: configured RestAPI instance
    */
    init(baseUrl: String, accessToken: String) {
        self.initialize(baseUrl, accessToken:accessToken)
    }
    
    /**
    Initialize the object with given parameters.
    
    - parameter baseUrl:     API Base URL. Should be obtained from Configuration
    - parameter accessToken: the access token used for all HTTP requests. Should be provided by user
    or from configuration (Configuration)
    */
    func initialize(baseUrl: String, accessToken: String) {
        ValidationUtils.validateUrl(baseUrl, { (error: RestError, res: RestResponse?) -> () in
            showAlert("Error", message: error.getMessage())
        })
        self.baseUrl = baseUrl
        self.accessToken = accessToken
    }
    
    /**
    Send given request, parse response into JSON object (for any HTTP code)
    and handle common errors from the JSON object.
    For all HTTP codes callback is invoked if there is a JSON response.
    This method is a wrapper for another send(..) method.
    
    - parameter request:       the request to send through raw RestAPI
    - parameter callback:      callback block used to return not nil JSON object parsed from the response
    - parameter errorCallback: callback block used to notify about an error occurred while processing the request
    */
    func sendAndHandleCommonErrors(request: RestRequest,
        withJSONCallback callback: (JSON, RestResponse?)->(), errorCallback: (RestError, RestResponse?)->()) {
        send(request, withJSONCallback: callback) { (error: RestError, response: RestResponse?) -> () in
            
            // Process common errors in error JSON response
            if let json = error.jsonResponse {
                self.handleJsonResponse(json, response: response, callback: callback, errorCallback: errorCallback)
            }
            else {
                errorCallback(error, response)
            }
        }
    }
    
    /**
    Send given request, parse response into JSON object and handle common errors from the JSON object.
    If HTTP code is not 20*, then errorCallback is invoked.
    
    - parameter request:       the request to send through raw RestAPI
    - parameter callback:      callback block used to return not nil JSON object parsed from the response
    - parameter errorCallback: callback block used to notify about an error occurred while processing the request
    */
    func send(request: RestRequest,
        withJSONCallback callback: (JSON, RestResponse?)->(), errorCallback: (RestError, RestResponse?)->()) {
            
            send(request, callback: { (response: RestResponse?) -> () in
                if let object: AnyObject = response?.responseObject?.value {
                    let json = JSON(object)
                    
                    self.handleJsonResponse(json, response: response, callback: callback, errorCallback: errorCallback)
                }
                else {
                    errorCallback(RestError.errorWithMessage("Null response received"), response)
                }
                }, errorCallback: { (error: RestError, response: RestResponse?)->() in
                    
                    // Parse response into errorObject
                    if let object: AnyObject = response?.responseObject?.value {
                        let json = JSON(object)
                        if json.type != .Unknown {
                            error.jsonResponse = json
                        }
                    }
                    errorCallback(error, response)
            })
    }
    
    /**
    Check if response contains errors and invoke errorCallback, else invoke callback
    
    - parameter json:          JSON data from the response
    - parameter response:      the response
    - parameter callback:      callback block used to return not nil JSON object parsed from the response
    - parameter errorCallback: callback block used to notify about an error occurred while processing the request
    */
    func handleJsonResponse(json: JSON, response: RestResponse?,
        callback: (JSON, RestResponse?)->(), errorCallback: (RestError, RestResponse?)->()) {
            
            // If there is an error inside the JSON response
            if let _ = json["error"].string {
                let errorMessage = json["message"].string ?? "Unknown_server_error"
                errorCallback(RestError.errorWithMessage(errorMessage), response)
            }
            else {
                if let array = json.array {
                    if array.count > 0 {
                        self.handleJsonResponse(array[0], response: response, callback: { (item0, res) -> () in
                            callback(json, response)
                        }, errorCallback: errorCallback)
                    }
                }
                else {
                    // Success response
                    callback(json, response)
                }
            }
    }
    
    /**
    Send given request and handle passing either a received response or an error through
    corresponding callback parameters.
    
    - parameter request:        the request to send
    - parameter callback:       callback block to return a received response
    - parameter errorCallback:  callback block to return an occurred error and optionally a response
    */
    func send(request: RestRequest, callback: (RestResponse)->(), errorCallback: (RestError, RestResponse?)->()) {
        let mainQueueErrorCallback = getMainQueueCallback(errorCallback)
        
        // Verify parameters
        if request.method == nil {
            mainQueueErrorCallback(RestError.parameterError("request.method",
                errorMessage: "HTTP Method is not specified. Please setup RestRequest correctly"), nil)
            return
        }
        
        if let r = createAlamofireRequestForMethod(request, mainQueueErrorCallback) {
            logRequest(r, request.needToLogBody)
            
            let completionHandler = { (response: Alamofire.Response<AnyObject, NSError>) -> Void in
                self.logResponse(response.response, response.result.value)
                
                let restResponse = self.convertResponse(response.response, responseObject: response.result)
                
                // If there is an error
                if response.result.isFailure {
                    NSNotificationCenter.defaultCenter().postNotificationName(LoggerNotifications.Error.rawValue,
                        object: response.result.value)
                    mainQueueErrorCallback(RestError.errorFromResponse(response.result.value as? NSData,
                        statusCode: restResponse.statusCode ?? 0), restResponse)
                }

                else {
                    // Check Http code
                    if restResponse.statusCode >= HttpStatusCode.ClientError.rawValue {
                        let httpError = RestError.errorFromResponse(restResponse.responseObject?.value as? NSData,
                            statusCode: restResponse.statusCode!)
                        
                        mainQueueErrorCallback(httpError, restResponse)
                    }
                    // Success request result
                    else {
                        dispatch_async(dispatch_get_main_queue()) {
                            callback(restResponse)
                        }
                    }
                }
            }
            
            // Send request
            switch request.responseType {
            case .JSON:
                r.responseJSON(options: .AllowFragments, completionHandler: completionHandler)
            default:
                mainQueueErrorCallback(RestError.errorWithMessage("Not supported response type:"
                    + "\(request.responseType)"), nil)
            }
        }
    }
    
    // MARK: Non-public methods
    
    /**
    Wrap given callback to be invoked in the main queue.
    
    - parameter callback: the callback block
    
    - returns: a block that invokes the given callback in main queue.
    */
    private func getMainQueueCallback(callback: (RestError, RestResponse?)->()) -> ((RestError, RestResponse?)->()) {
        return { (error: RestError, response: RestResponse?)->() in
            dispatch_async(dispatch_get_main_queue()) {
                callback(error, response)
            }
        }
    }
    
    /**
    Construct RestResponse from NSHTTPURLResponse
    
    - parameter response:       the response received from the server
    - parameter responseObject: the object created from response body or nil
    
    - returns: RestResponse instance
    */
    private func convertResponse(response: NSHTTPURLResponse?, responseObject: Result<AnyObject, NSError>?) -> RestResponse {
        let restResponse = RestResponse(responseObject: responseObject)
        if let res = response {
            restResponse.headers = res.allHeaderFields as? Dictionary<String,String>
            restResponse.statusCode = res.statusCode
            restResponse.URL = res.URL
            restResponse.mimeType = res.MIMEType
        }
        return restResponse
    }
    
    /**
    Notifies with given request URL, Method and body
    
    - parameter alamofireRequest: the request to log
    - parameter needToLogBody:    flag used to decide either to log body or not
    */
    private func logRequest(alamofireRequest: Request, _ needToLogBody: Bool) {
        let request = alamofireRequest.request
        // Log request URL
        var info = "url"
        if let m = request?.HTTPMethod { info = m }
        var logMessage = "request \(info): \(request!.URL!.absoluteString)"
        
        if needToLogBody {
            // log body if set
            if let body = request?.HTTPBody {
                if let bodyAsString = NSString(data: body, encoding: NSUTF8StringEncoding) {
                    logMessage += "\n\tbody: \(bodyAsString)"
                }
            }
        }
        if let auth = request?.valueForHTTPHeaderField(AUTH_HEADER) {
            logMessage += "\n\t\(AUTH_HEADER): \(auth)"
        }
        NSNotificationCenter.defaultCenter().postNotificationName(LoggerNotifications.Request.rawValue,
            object: logMessage)
        
    }
    
    /**
    Notifies with given response object.
    
    - parameter response: HTTP response
    - parameter object:   response object
    */
    private func logResponse(response: NSHTTPURLResponse?, _ object: AnyObject?) {
        var info: String = response != nil ? "HTTP \(response!.statusCode) " : ""
        if let o: AnyObject = object {
            if let data = o as? NSData {
                info += "NSData[length=\(data.length)]"
            }
            else {
                info += o.description
            }
        }
        else {
            info += "<null response>"
        }
        NSNotificationCenter.defaultCenter().postNotificationName(LoggerNotifications.Response.rawValue,
            object: info)
    }
    
    /**
    Create Alamofire Request instance from given RestRequest.
    RestRequest provides an abstraction that is currently implemented with Alamofire framework.
    Changing the underlying framework to another one will affect only RestAPI class, not its clients.
    Any created request has JSON encoding.
    
    - parameter request:        the request to convert to Alamofire Request
    - parameter errorCallback:  callback block to notify about an occurred error
    
    - returns: created request or nil
    */
    private func createAlamofireRequestForMethod(request: RestRequest, _ errorCallback: (RestError, RestResponse?)->())
        -> Request? {
        
        // Build a full URL from pieces incorporated in RestRequest
        var url = request.buildFullUrl(baseUrl)
        
        if !ValidationUtils.validateUrl(url, errorCallback) { return nil }
        
        let urlRequest = NSMutableURLRequest(URL: NSURL(string: url)!)
        urlRequest.HTTPMethod = request.method.rawValue
            
        // Include GET parameters in URL
        if request.method! == .GET {
            if let params = request.parameters {
                for (k,v) in params {
                    if let value = v as? String {
                        url += "&\(k)=\(value.urlEncodedString())"
                    }
                }
            }
        }
        else {
            if let parameters = request.parameters {
                do {
                    try urlRequest.HTTPBody = NSJSONSerialization.dataWithJSONObject(parameters, options: NSJSONWritingOptions.PrettyPrinted)
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
                catch {
                    // nothing to do
                }
            }
        }
        
        // Headers
        if let accessToken = getAccessToken(request) {
            urlRequest.setValue(accessToken, forHTTPHeaderField: AUTH_HEADER)
        }
        if let headers = request.headers {
            for (k,v) in headers {
                urlRequest.setValue(v, forHTTPHeaderField: k)
            }
        }
            
        return Alamofire.request(urlRequest)
    }
    
    /**
    Get access token for HTTP request header.
    
    - parameter request: the request
    
    - returns: the access token or nil
    */
    private func getAccessToken(request: RestRequest) -> String? {
        
        // Try to use access token from Request
        if let token = request.accessToken {
            if !token.isEmpty {
                return token
            }
        }
        
        // Try to use default access token
        if !self.accessToken.isEmpty {
            return self.accessToken
        }
        return nil
    }
}