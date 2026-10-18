import Foundation
import CLicensebox

public struct LicenseboxError: Error, CustomStringConvertible {
    public let code: String
    public let description: String
    public init(_ code: String, _ message: String? = nil) { self.code=code;description=message ?? code }
}
public struct Callbacks {
    public var onSignIn: ((String,String) throws -> Void)?
    public var clock: (() throws -> Double)?
    public var machineBinding: (() throws -> String)?
    public var cancelled: (() throws -> Bool)?
    public init(onSignIn: ((String,String) throws -> Void)? = nil,clock: (() throws -> Double)? = nil,machineBinding: (() throws -> String)? = nil,cancelled: (() throws -> Bool)? = nil) {
        self.onSignIn=onSignIn;self.clock=clock;self.machineBinding=machineBinding;self.cancelled=cancelled
    }
}
private final class CallbackState {
    let callbacks:Callbacks
    var error:Error?
    init(_ callbacks:Callbacks){self.callbacks=callbacks}
}
private func state(_ p:UnsafeMutableRawPointer?) -> CallbackState { Unmanaged<CallbackState>.fromOpaque(p!).takeUnretainedValue() }
private func text(_ p:UnsafePointer<CChar>?) -> String { p.map{String(cString:$0)} ?? "" }
private func checked(_ s:String) throws -> String {if s.utf8.contains(0){throw LicenseboxError("invalid_argument","NUL in argument")};return s}
private func json(_ value:Any) throws -> String {String(decoding:try JSONSerialization.data(withJSONObject:value,options:[.fragmentsAllowed,.sortedKeys]),as:UTF8.self)}
private func owned(_ p:UnsafeMutablePointer<CChar>?) throws -> Any {
    guard let p=p else {throw LicenseboxError("protocol_error")};defer{lb_free(p)}
    return try JSONSerialization.jsonObject(with:Data(String(cString:p).utf8),options:.fragmentsAllowed)
}
private func error(_ rc:lb_result,_ handle:OpaquePointer? = nil) -> LicenseboxError {
    let fallback=text(lb_result_code(rc));guard let h=handle,rc != LB_INVALID_ARGUMENT else{return LicenseboxError(fallback)}
    let code=text(lb_error_code(h)),message=text(lb_error_message(h));return LicenseboxError(code == "ok" ? fallback:code,message.isEmpty ? fallback:message)
}
public final class Client {
    private var handle:OpaquePointer?
    private let callbackState:CallbackState
    private let lock=NSRecursiveLock()
    private var busy=false
    public init(product:String,keys:[String:String],version:String="",server:String?=nil,directory:String?=nil,caBundle:String?=nil,callbacks:Callbacks=Callbacks()) throws {
        callbackState=CallbackState(callbacks)
        var options:[String:Any] = ["product":try checked(product),"keys":keys,"version":try checked(version)]
        if let value=server{options["server"]=try checked(value)};if let value=directory{options["directory"]=try checked(value)};if let value=caBundle{options["ca_bundle"]=try checked(value)}
        var cb=lb_callbacks();cb.context=Unmanaged.passUnretained(callbackState).toOpaque()
        if callbacks.onSignIn != nil {cb.on_sign_in={p,u,c in let s=state(p);do{try s.callbacks.onSignIn?(text(u),text(c))}catch{s.error=error}}}
        if callbacks.clock != nil {cb.clock={p in let s=state(p);do{let n=try s.callbacks.clock!();guard n.isFinite else{throw LicenseboxError("invalid_argument","Invalid clock")};return n}catch{s.error=error;return 0}}}
        if callbacks.machineBinding != nil {cb.machine_binding={p,out,cap in let s=state(p);do{let v=try checked(s.callbacks.machineBinding!());let bytes=Array(v.utf8);guard bytes.count<Int(cap),let out=out else{throw LicenseboxError("invalid_argument")};for(i,b)in bytes.enumerated(){out[i]=CChar(bitPattern:b)};out[bytes.count]=0;return 0}catch{s.error=error;return 1}}}
        cb.cancelled={p in let s=state(p);if s.error != nil{return 1};do{return try s.callbacks.cancelled?() == true ? 1:0}catch{s.error=error;return 1}}
        let encoded=try json(options);let rc=encoded.withCString{lb_client_create_json($0,&cb,&handle)}
        if let e=callbackState.error{if let h=handle{lb_client_destroy(h);handle=nil};throw e}
        if rc != LB_OK{throw error(rc)}
    }
    deinit {if let h=handle{lb_client_destroy(h)}}
    public func close() throws {
        lock.lock();defer{lock.unlock()};guard !busy else{throw LicenseboxError("invalid_argument","Callbacks must not reenter client")}
        if let h=handle{lb_client_destroy(h);handle=nil}
    }
    private func call(_ operation:String,_ arguments:[String:Any]=[:]) throws -> Any {
        lock.lock();defer{lock.unlock()};guard let h=handle else{throw LicenseboxError("closed")};guard !busy else{throw LicenseboxError("invalid_argument","Callbacks must not reenter client")}
        let encoded=try json(arguments);busy=true;defer{busy=false};var out:UnsafeMutablePointer<CChar>?
        let rc=operation.withCString{o in encoded.withCString{lb_client_call_json(h,o,$0,&out)}}
        if let e=callbackState.error{callbackState.error=nil;lb_free(out);throw e};if rc != LB_OK{lb_free(out);throw error(rc,h)}
        return try owned(out)
    }
    public func lease() throws -> Any {try call("lease")}
    /// Explicit bounded renewal; scheduling and safe work cancellation belong to the caller.
    public func heartbeat(_ module:String) throws -> Any {try call("heartbeat",["module":try checked(module)])}
    public func require(_ module:String) throws -> Any {try call("require",["module":try checked(module)])}
    public func status() throws -> Any {try call("status")}
    public func signIn(timeout:Double=0) throws -> Any {try call("sign_in",["timeout":timeout])}
    public func logout() throws { _ = try call("logout") }
    public func modules() throws -> Any {try call("modules")}
    public func requests() throws -> Any {try call("requests")}
    public func requestAccess(_ modules:[String],note:String="") throws -> Any {try call("request",["modules":modules,"note":try checked(note)])}
    public func accessLink() throws -> String {guard let v=try call("access-link") as? String else{throw LicenseboxError("protocol_error")};return v}
    public func record(command:String,success:Bool,elapsed:Double) throws {_ = try call("record",["command":try checked(command),"success":success,"elapsed":elapsed])}
}
public func deriveBinding(product:String,source:String,rawID:String) throws -> String {
    let raw=String(rawID.reversed().drop(while:{$0 == "\0"}).reversed());var out=[CChar](repeating:0,count:128)
    let p=try checked(product),s=try checked(source),r=try checked(raw)
    let rc=p.withCString{p in s.withCString{s in r.withCString{lb_derive_binding(p,s,$0,&out,128)}}};if rc != LB_OK{throw error(rc)};return String(cString:out)
}
public func nativeBinding(product:String) throws -> String {var out=[CChar](repeating:0,count:128);let p=try checked(product);let rc=p.withCString{lb_native_binding($0,&out,128)};if rc != LB_OK{throw error(rc)};return String(cString:out)}
public func verifyLease(token:String,product:String,keys:[String:String],now:Double) throws -> Any {
    let t=try checked(token),p=try checked(product),k=try json(keys);var out:UnsafeMutablePointer<CChar>?
    let rc=t.withCString{t in p.withCString{p in k.withCString{lb_verify_lease_json(t,p,$0,now,&out)}}};if rc != LB_OK{lb_free(out);throw error(rc)};return try owned(out)
}
