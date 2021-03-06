//: Playground - noun: a place where people can play

import JavaScriptCore

/* Call javascript function ver1 */

let context:JSContext = JSContext()
context.evaluateScript("var factorial = function(n) { if(n<0){return;}if(n===0){return 1;}return n*factorial(n-1); }")
let result: JSValue = context.evaluateScript("factorial(3)")
print(result.toInt32())


/* Call javascript function ver2 */

//let context:JSContext = JSContext()
//context.evaluateScript("var factorial = function(n) { if(n<0){return;}if(n===0){return 1;}return n*factorial(n-1); }")
//let factorial:JSValue = context.objectForKeyedSubscript("factorial")
//let result:JSValue = factorial.callWithArguments([3])
//print(result.toInt32())

/* Retrieve JSValue test */

//context.evaluateScript("var areas = {'okinawa':['Ginowan', 'Urasoe', 'Naha']};")
//let areas = context.objectForKeyedSubscript("areas").toObject()
//areas["okinawa"]
//
//let withTransports = ["'polling'", "'websocket'"]
//withTransports.joinWithSeparator(",")


/* Call swift callback from javascript */
//let context = JSContext()
//let say: @convention(block) String -> String = { str in
//    return "say \(str)!"
//}
//context.setObject(unsafeBitCast(say, AnyObject!.self), forKeyedSubscript: "say")
//print(context.evaluateScript("say('hello')"))
//
//let sayFunc = context.objectForKeyedSubscript("say")
//print(sayFunc.callWithArguments(["hello2"]))

