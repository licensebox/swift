# Validation — 2026-10-18

UNVALIDATED locally: no Swift compiler installed. ci/test.sh performs actual SwiftPM build, XCTest lifecycle/callback tests, package checks and builds the Swift adapter. Run the shared 69-case suite on a Swift-enabled Ubuntu runner.

The C core was built as a shared library from the public SDK checkout. Test keys, times, identities and loopback server data are synthetic. Linux x86-64 only; other OS/runtime paths are unvalidated. No remote release or registry publication is performed by these scripts.
