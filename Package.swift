// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Licensebox",products:[.library(name:"Licensebox",targets:["Licensebox"]),.executable(name:"licensebox-adapter",targets:["LicenseboxAdapter"])],targets:[.systemLibrary(name:"CLicensebox"),.target(name:"Licensebox",dependencies:["CLicensebox"]),.executableTarget(name:"LicenseboxAdapter",dependencies:["Licensebox"]),.testTarget(name:"LicenseboxTests",dependencies:["Licensebox"])])
