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

// Thanks to http://stackoverflow.com/questions/24123518/how-to-use-cc-md5-method-in-swift-language
extension String  {
    var md5: String! {
        let str = self.cStringUsingEncoding(NSUTF8StringEncoding)
        let strLen = CC_LONG(self.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.alloc(digestLen)
        
        CC_MD5(str!, strLen, result)
        
        let hash = NSMutableString()
        for i in 0..<digestLen {
            hash.appendFormat("%02x", result[i])
        }
        
        result.dealloc(digestLen)
        
        return String(format: hash as String)
    }
}

typealias responseCallback = (SIOSocket!) -> Void
typealias OnConnect = () -> Void
typealias OnDisconnect = () -> Void
typealias OnError = ([String:AnyObject]) -> Void
typealias OnReconnect = (numberOfAttempts:Int) -> Void
typealias OnReconnectionAttempt = (numberOfAttempts:Int) -> Void
typealias OnReconnectionError = ([String:AnyObject]) -> Void

class SIOSocket : NSObject {
    
    var thread:NSThread!
    var javascriptWebView:UIWebView!
    var javascriptContext:JSContext!
    var onConnect:OnConnect!
    var onDisConnect:OnDisconnect!
    var onError:OnError!
    var onReconnect:OnReconnect!
    var onReconnectionAttempt:OnReconnectionAttempt!
    var onReconnectionError:OnReconnectionError!
    
    class func socketWithHost(hostUrl:String, response:responseCallback ) {
        return self.socketWithHost(
            hostUrl,
            reconnectAutomatically: true,
            attemptLimit: -1,
            withDelay: 1,
            maximumDelay: 5,
            timeout: 20,
            response: response)
    }
    
    class func socketWithHost(
        hostUrl:String,
        reconnectAutomatically:Bool,
        attemptLimit:Int,
        withDelay:NSTimeInterval,
        maximumDelay:NSTimeInterval,
        timeout:NSTimeInterval,
        response: responseCallback) {
            
            return self.socketWithHost(hostUrl, reconnectAutomatically: reconnectAutomatically, attemptLimit: attemptLimit, withDelay: withDelay, maximumDelay: maximumDelay, timeout: timeout, withTransports: ["polling", "websocket"], response: response)
    }
    
    class func socketWithHost(
        hostUrl:String,
        reconnectAutomatically:Bool,
        attemptLimit:Int,
        withDelay:NSTimeInterval,
        maximumDelay:NSTimeInterval,
        timeout:NSTimeInterval,
        withTransports:Array<String>,
        response: responseCallback) {
            
            let socket = SIOSocket()
            
            socket.javascriptWebView = UIWebView()
            if let ctx = socket.javascriptWebView.valueForKeyPath("documentView.webView.mainFrame.javaScriptContext") {
                socket.javascriptContext = ctx as! JSContext
            } else {
                response(nil)
                return
            }
            
            socket.javascriptContext.exceptionHandler = { context, errorValue in
                print("JSError: \(errorValue)")
                print("\(NSThread.callStackSymbols())")
            }
            
            let onLoad: @convention(block) () -> Void = { [weak socket] in
                
                if let socket = socket {
                    socket.thread = NSThread.currentThread()
                    
                    // Load socketio.js
                    socket.javascriptContext.evaluateScript(Consts.socket_io_js)
                    // Load helper blob method
                    socket.javascriptContext.evaluateScript(Consts.blob_factory_js)
                    
                    // Load socket.io constractor
                    let socketConstructor = Consts.socket_io_js_constructor(hostUrl, reconnection: reconnectAutomatically, attemptLimit: attemptLimit, reconnectionDelay: withDelay, reconnectionDelayMax: maximumDelay, timeout: timeout, transports: withTransports)
                    socket.javascriptContext.setObject(socket.javascriptContext.evaluateScript(socketConstructor), forKeyedSubscript: "swift_socket")
                    if socket.javascriptContext.objectForKeyedSubscript("swift_socket").toObject() == nil {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
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
                    
                    socket.javascriptContext.setObject(unsafeBitCast(onConnectCallBack, AnyObject.self), forKeyedSubscript: "swift_onConnect")
                    socket.javascriptContext.setObject(unsafeBitCast(onDisconnect, AnyObject.self), forKeyedSubscript: "swift_onDisconnect")
                    socket.javascriptContext.setObject(unsafeBitCast(onError, AnyObject.self), forKeyedSubscript: "swift_onError")
                    socket.javascriptContext.setObject(unsafeBitCast(onReconnect, AnyObject.self), forKeyedSubscript: "swift_onReconnect")
                    socket.javascriptContext.setObject(unsafeBitCast(onReconnectionAttempt, AnyObject.self), forKeyedSubscript: "swift_onReconnectionAttempt")
                    socket.javascriptContext.setObject(unsafeBitCast(onReconnectionError, AnyObject.self), forKeyedSubscript: "swift_onReconnectionError")
                    
                    socket.javascriptContext.evaluateScript("swift_socket.on('connect', swift_onConnect);")
                    socket.javascriptContext.evaluateScript("swift_socket.on('error', swift_onError);")
                    socket.javascriptContext.evaluateScript("swift_socket.on('disconnect', swift_onDisconnect);")
                    socket.javascriptContext.evaluateScript("swift_socket.on('reconnect', swift_onReconnect);")
                    socket.javascriptContext.evaluateScript("swift_socket.on('reconnecting', swift_onReconnectionAttempt);")
                    socket.javascriptContext.evaluateScript("swift_socket.on('reconnect_error', swift_onReconnectionError);")

                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        response(socket)
                    })
//            let onLoadTest: @convention(block) () -> Void = { [weak socket] in
//                print("hello: \(socket)")
//            }
                    
            }
            else {
                print("couldn't catch socket in onLoad callback with some unkown reason.")
                response(nil)
                }
            }

            socket.javascriptContext.setObject(unsafeBitCast(onLoad, AnyObject!.self), forKeyedSubscript: "swift_onloadCallback")
            socket.javascriptContext.evaluateScript("window.onload = swift_onloadCallback;")
            socket.javascriptWebView.loadHTMLString("<html/>", baseURL: nil)
    }
    
    func on(event:String, callback:[AnyObject] -> Void) {
        let eventId = event.md5
        let callbackFunc: @convention(block) () -> Void = {
            var arguments = [AnyObject]()
            for object in JSContext.currentArguments() {
                if object.toObject() != nil {
                    arguments.append(object)
                }
            }
        }
        
        self.javascriptContext.setObject(unsafeBitCast(callbackFunc, AnyObject.self), forKeyedSubscript: "swift_\(eventId)")
        let script = "swift_socket.on('\(event)', swift_\(eventId));"
        self.performSelector("evaluateScript:", onThread: self.thread, withObject: script, waitUntilDone: false)
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
        
        let script = "swift_socket.emit(\(arguments.joinWithSeparator(",")));"
        self.performSelector("evaluateScript:", onThread: self.thread, withObject: script, waitUntilDone: false)
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