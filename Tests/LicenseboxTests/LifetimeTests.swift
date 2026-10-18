import XCTest
@testable import Licensebox
final class LifetimeTests:XCTestCase {
 func testCloseAndRepeatedAllocation() throws {
  let d=NSTemporaryDirectory()+UUID().uuidString
  for _ in 0..<100 {let c=try Client(product:"demo",keys:["test-key":"A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg"],directory:d);try c.close();XCTAssertThrowsError(try c.status())}
 }
 func testThrowingCallback() throws {
  struct Failure:Error{}
  let c = try Client(product:"demo",keys:["test-key":"A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg"],directory:NSTemporaryDirectory()+UUID().uuidString,callbacks:Callbacks(machineBinding:{throw Failure()}))
  defer { try? c.close() }
  XCTAssertThrowsError(try c.signIn(timeout:0.1))
 }
}
