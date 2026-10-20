# Licensebox for Swift

Application licensing SDK by [Vijai Kumar](https://meshing.engineer). MIT, 2026.
Uses the maintained Licensebox C core **>=0.5.0** for HTTPS, hybrid Ed25519 + ML-DSA-65 verification, native machine identity, persistence, activation, offline access, policy refusals and bounded usage collection. No licensing server or administration credentials are included.

## Build and install

Swift >=5.9. On GitHub Actions use swift-actions/setup-swift before ci/setup.sh.
Build/install the public [C core](https://github.com/licensebox/c) as a shared library first. Export `LICENSEBOX_LIB_DIR` (directory containing liblicensebox.so), `LICENSEBOX_INCLUDE_DIR` (public headers), and `LD_LIBRARY_PATH`. `LICENSEBOX_LIBRARY` may identify the library path; scripts derive its containing directory when supplied. Linked bindings resolve liblicensebox.so through the native dynamic loader, so use a compatible library basename. CI uses only a disposable Ubuntu runner; ci/setup.sh is not a workstation installer.

```sh
bash ci/setup.sh
bash ci/test.sh
python3 ../protocol/conformance/run.py --adapter bash ci/adapter.sh
```

`ci/test.sh` builds real language code and runs repeated allocation/close checks, then creates or installs the language package. The adapter is test-only and supplies synthetic clock/binding callbacks. It is not a production command-line bypass.

## Use

```
import Licensebox
let client = try Client(product: "your-product", keys: ["signing-key-id":"PUBLIC_BASE64URL_KEY"],
                        version: "1.0", callbacks: Callbacks(onSignIn: { url, code in print(url, code) }))
defer { try? client.close() }
_ = try client.require("core") // Check before opening user files.
```

Explicitly sign in using the sign-in method when the user chooses to activate. Retain one client per process and close it deterministically. A protected call renews silently with a short bound; verified unexpired offline access is allowed only for eligible transport/server failures. Expiry returns offline and does not automatically activate. Explicit policy refusals persist and block cached access. Native identity is never replaced with random, hostname or network identifiers.

## API

`lease`, `require`, `status`, `signIn`, `logout`, `modules`, `requests`, `requestAccess`, `accessLink`, `record`; global `deriveBinding`, `nativeBinding`, `verifyLease`. JSON result objects use Foundation types; accessLink returns String.

Constructor options include version, server, directory and optional ca_bundle. TLS certificate and hostname verification stay enabled. The sign-in callback receives the verification URL and user code. Clock, machine binding and cancellation are **typed trusted application callbacks**, not JSON option overrides or end-user settings. Callback state stays alive for the native client's lifetime. Exceptions are contained at the FFI boundary and reported after native execution. Callbacks must not reenter the client; the wrapper rejects reentry. Calls and error inspection are serialized; do not move language runtime handles between unsupported threads.

Access links, leases and private device codes are credentials; avoid logs. Keep public verification keys in the application and installation private keys local. Collect fixed-command usage only; never filenames, arguments or file data.

## Validation

Linux is the target native profile. See VALIDATION.md for the exact checks run. Windows and macOS runtime paths are unvalidated.

The exact public protocol pin is protocol-lock.json; native-version.txt records the minimum C release. Follow [the shared contract](https://github.com/licensebox/protocol) before changing licensing behavior. Administration remains in the Go CLI.

## Optional explicit heartbeat

Use `try client.heartbeat("core")` for an explicit bounded renewal/checkpoint. The mandatory module must be nonempty. The result contains `lease` (the complete verified lease, preserving optional signed `heartbeat.interval_seconds`/`grace_seconds`) and `online` (whether this check renewed successfully online). Every invocation attempts renewal, including after a cached `Require`; it never starts interactive activation or transfers a seat. Eligible outages may return `online=false` only while the last verified signed lease remains unexpired. Refusals, missing modules and expired offline access remain errors.

Default Client/Lease/Require behavior is unchanged. No timer, task, thread or background heartbeat starts automatically. The application owns event-loop scheduling/checkpoints on the language runtime thread, and safe cancellation of protected work on refusal or the last verified expiry deadline. A failed check cannot extend that deadline. This is especially important for MATLAB, Wolfram/JLink and other runtimes whose callbacks must stay on their owning thread. The matching native C heartbeat API/contract is required.

Validate the feature against the candidate native core with `python3 ../protocol/conformance/heartbeat.py --adapter bash ci/adapter.sh` in addition to the existing full shared suite.
