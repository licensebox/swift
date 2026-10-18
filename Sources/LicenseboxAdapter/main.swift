import Foundation
import Licensebox
func run(_ r:[String:Any]) throws -> Any {
 let op=r["op"] as! String,p=r["product"] as! String
 if op=="derive" {return try deriveBinding(product:p,source:r["source"] as! String,rawID:r["raw_id"] as! String)}
 if op=="native" {return try nativeBinding(product:p)}
 let keys=r["keys"] as! [String:String],now=(r["now"] as! NSNumber).doubleValue
 if op=="verify" {return try verifyLease(token:r["token"] as! String,product:p,keys:keys,now:now)}
 let c=try Client(product:p,keys:keys,version:"conformance",server:r["server"] as? String,directory:r["directory"] as? String,caBundle:r["ca_bundle"] as? String,callbacks:Callbacks(onSignIn:{_,_ in},clock:{now},machineBinding:{r["binding"] as? String ?? ""}))
 defer{try? c.close()}
 switch op {
 case "lease":return try c.lease()
 case "require":return try c.require(r["module"] as? String ?? "core")
 case "repeat":_ = try c.require("core");return try c.require("core")
 case "status":return try c.status()
 case "sign_in":return try c.signIn(timeout:3)
 case "logout":try c.logout();return NSNull()
 case "modules":return try c.modules()
 case "requests":return try c.requests()
 case "request":return try c.requestAccess(["export"],note:"café – test")
 case "access-link":return try c.accessLink()
 case "record":try c.record(command:"export",success:true,elapsed:0.125);try c.record(command:"export",success:false,elapsed:0.025);return NSNull()
 default:throw LicenseboxError("invalid_argument")
 }
}
let r=try JSONSerialization.jsonObject(with:FileHandle.standardInput.readDataToEndOfFile()) as! [String:Any]
var answer:[String:Any]
do{answer=["ok":true,"value":try run(r)]}catch let e as LicenseboxError{answer=["ok":false,"error":e.code]}
let output=try JSONSerialization.data(withJSONObject:answer,options:[.sortedKeys]);print(String(decoding:output,as:UTF8.self))
