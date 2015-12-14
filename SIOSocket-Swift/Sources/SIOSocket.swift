//
//  SIOSocket.swift
//  SIOSocket-Swift
//
//  Created by Yuhei Miyazato on 11/26/15.
//  Copyright © 2015 mitolab. All rights reserved.
//

import Foundation
import UIKit
import JavaScriptCore
import CryptoSwift

struct SIOSocketConsts {
    
    static let MSEC_PER_SEC = 1000
    static let blob_factory_js = "function blob(dataString) {var blob = new Blob([dataString], {type: \'text/plain\'});return blob;}"
}

typealias responseCallback = (SIOSocket?) -> Void
typealias OnConnect = () -> Void
typealias OnDisconnect = () -> Void
typealias OnError = ([String:AnyObject]) -> Void
typealias OnReconnect = (numberOfAttempts:Int) -> Void
typealias OnReconnectionAttempt = (numberOfAttempts:Int) -> Void
typealias OnReconnectionError = ([String:AnyObject]) -> Void

class SIOSocket : NSObject {
    
    var javascriptWebView:UIWebView!
    var javascriptContext:JSContext!
    var onConnect:OnConnect!
    var onDisConnect:OnDisconnect!
    var onError:OnError!
    var onReconnect:OnReconnect!
    var onReconnectionAttempt:OnReconnectionAttempt!
    var onReconnectionError:OnReconnectionError!
    
    class func socketWithHost(hostUrl:String, response:responseCallback )  -> SIOSocket? {
        return self.socketWithHost(
            hostUrl,
            reconnectAutomatically: true,
            attemptLimit: -1,
            withDelay: 1,
            maximumDelay: 5,
            timeout: 20,
            withTransports: ["polling", "websocket"],
            response: response)
    }
    
    class func socketWithHost(
        hostUrl:String,
        reconnectAutomatically:Bool,
        attemptLimit:Int,
        withDelay:NSTimeInterval,
        maximumDelay:NSTimeInterval,
        timeout:NSTimeInterval,
        withTransports:Array<String>,
        response: responseCallback) -> SIOSocket? {
            
            let socket = SIOSocket()
            
            socket.javascriptWebView = UIWebView()
            if let ctx = socket.javascriptWebView.valueForKeyPath("documentView.webView.mainFrame.javaScriptContext") {
                socket.javascriptContext = ctx as! JSContext
            } else {
                response(nil)
                return nil
            }
            
            socket.javascriptContext.exceptionHandler = { context, errorValue in
                print("JSError: \(errorValue)")
                //print("\(NSThread.callStackSymbols())")
            }
            
            let onLoad: @convention(block) () -> Void = {
                
                let context = JSContext.currentContext()
                
                let path = NSBundle.mainBundle().pathForResource("socket.io-1.3.7",ofType:"js")
                let socket_io_js = try! String(contentsOfFile: path!, encoding: NSUTF8StringEncoding)
                context.evaluateScript(socket_io_js)
                context.evaluateScript(SIOSocketConsts.blob_factory_js)

                let io = context.objectForKeyedSubscript("io")
                let swiftSocket = io.callWithArguments([
                        hostUrl, [
                            "reconnection": reconnectAutomatically,
                            "reconnectionAttempts": attemptLimit == -1 ? "Infinity" : attemptLimit.description,
                            "reconnectionDelay": Int(withDelay) * SIOSocketConsts.MSEC_PER_SEC,
                            "reconnectionDelayMax": Int(maximumDelay) * SIOSocketConsts.MSEC_PER_SEC,
                            "timeout": Int(timeout) * SIOSocketConsts.MSEC_PER_SEC,
                            "transports": withTransports
                        ]
                    ])
                context.setObject(swiftSocket, forKeyedSubscript: "swift_socket")
                if context.objectForKeyedSubscript("swift_socket").toObject() == nil {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        print("swift_socket is not created")
                        response(nil)
                    })
                }
                
                /* Set swift callbacks when socket.io(js) callback called.
                 * Corresponding with events in http://socket.io/docs/client-api/
                 */
                
                let onConnectCallBack: @convention(block) () -> Void = { [weak socket] in
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        if socket == nil { response(nil); return }
                        if socket!.onConnect != nil {
                            socket!.onConnect()
                        }
                    })
                }
                
                let onDisconnect: @convention(block) () -> Void = { [weak socket] in
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        if socket == nil { response(nil); return }
                        if socket!.onDisConnect != nil {
                            socket!.onDisConnect()
                        }
                    })
                }
                
                let onError: @convention(block) ([String:AnyObject]) -> Void = { [weak socket] (errorInfo: [String:AnyObject]) in
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        if socket == nil { response(nil); return }
                        if socket!.onError != nil {
                            socket!.onError(errorInfo)
                        }
                    })
                }
                
                let onReconnect: @convention(block) (Int) -> Void = { [weak socket] (numberOfAttempts:Int) in
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        if socket == nil { response(nil); return }
                        if socket!.onReconnect != nil {
                            socket!.onReconnect(numberOfAttempts: numberOfAttempts)
                        }
                    })
                }
                
                let onReconnectionAttempt: @convention(block) (Int) -> Void = { [weak socket] (numberOfAttempts:Int) in
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        if socket == nil { response(nil); return }
                        if socket!.onReconnectionAttempt != nil {
                            socket!.onReconnectionAttempt(numberOfAttempts: numberOfAttempts)
                        }
                    })
                }
                
                let onReconnectionError: @convention(block) ([String:AnyObject]) -> Void = { [weak socket] (errorInfo: [String:AnyObject]) in
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        if socket == nil { response(nil); return }
                        if socket!.onReconnectionError != nil {
                            socket!.onReconnectionError(errorInfo)
                        }
                    })
                }
                
                context.setObject(unsafeBitCast(onConnectCallBack, AnyObject.self), forKeyedSubscript: "swift_onConnect")
                context.setObject(unsafeBitCast(onDisconnect, AnyObject.self), forKeyedSubscript: "swift_onDisconnect")
                context.setObject(unsafeBitCast(onError, AnyObject.self), forKeyedSubscript: "swift_onError")
                context.setObject(unsafeBitCast(onReconnect, AnyObject.self), forKeyedSubscript: "swift_onReconnect")
                context.setObject(unsafeBitCast(onReconnectionAttempt, AnyObject.self), forKeyedSubscript: "swift_onReconnectionAttempt")
                context.setObject(unsafeBitCast(onReconnectionError, AnyObject.self), forKeyedSubscript: "swift_onReconnectionError")
                
                context.evaluateScript("swift_socket.on('connect', swift_onConnect);")
                context.evaluateScript("swift_socket.on('error', swift_onError);")
                context.evaluateScript("swift_socket.on('disconnect', swift_onDisconnect);")
                context.evaluateScript("swift_socket.on('reconnect', swift_onReconnect);")
                context.evaluateScript("swift_socket.on('reconnecting', swift_onReconnectionAttempt);")
                context.evaluateScript("swift_socket.on('reconnect_error', swift_onReconnectionError);")

                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    response(socket)
                })
            }

            socket.javascriptContext.setObject(unsafeBitCast(onLoad, AnyObject!.self), forKeyedSubscript: "swift_onloadCallback")
            socket.javascriptContext.evaluateScript("window.onload = swift_onloadCallback;")
            socket.javascriptWebView.loadHTMLString("<html/>", baseURL: nil)
            
            return socket
    }
    
    func on(event:String, callback:[AnyObject] -> Void) {
        let eventId = event.md5()
        let callbackFunc: @convention(block) () -> Void = {
            var arguments = [AnyObject]()
            for object in JSContext.currentArguments() {
                if object.toObject() != nil {
                    arguments.append(object)
                }
            }
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                callback(arguments)
            })
        }

        self.javascriptContext.setObject(unsafeBitCast(callbackFunc, AnyObject.self), forKeyedSubscript: "swift_\(eventId)")
        self.evaluateScript("swift_socket.on('\(event)', swift_\(eventId));")
    }
    
    func emit(event:String) {
        self.emit(event, args: nil)
    }
    
    func emit(event:String, args:[AnyObject]? ) {
        var arguments = [String]()
        arguments.append("'\(event)'")
        
        if let args = args {
            for arg in args {
                if arg is NSNull {
                    arguments.append("null")
                }
                else if arg is String {
                    arguments.append("'\(arg)'")
                }
                else if arg is NSNumber {
                    arguments.append("\(arg)")
                }
                else if arg is NSData {
                    let dataStr = String(data: arg as! NSData, encoding: NSUTF8StringEncoding)
                    arguments.append("blob('\(dataStr)')")
                }
                else if arg is Array<AnyObject> || arg is Dictionary<String, AnyObject> {
                    if NSJSONSerialization.isValidJSONObject(arg) {
                        do {
                            let serializedData = try NSJSONSerialization.dataWithJSONObject(arg, options: NSJSONWritingOptions(rawValue: 0))
                            arguments.append(String(data: serializedData, encoding: NSUTF8StringEncoding)!)
                        } catch {
                            print("emit parameter json serialization went wrong.")
                        }
                    } else {
                        print("emit parameter json is not a valid form.")
                    }
                }
            }
        }
        
        self.evaluateScript("swift_socket.emit(\(arguments.joinWithSeparator(",")));")
    }
    
    func evaluateScript(script:String) {
        self.javascriptContext.evaluateScript(script)
    }
    
    func close() {
        self.javascriptWebView.loadRequest(NSURLRequest(URL: NSURL(string: "about:blank")!))
        self.javascriptWebView.reload()
        self.javascriptWebView = nil
    }
}