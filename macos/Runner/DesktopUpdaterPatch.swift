import Cocoa
import FlutterMacOS

// Patches the desktop_updater plugin's restartApp method, which has a bug where
// NSApplication.terminate() is called before copying files and relaunching, so
// neither the copy nor the relaunch ever executes.
class DesktopUpdaterPatch {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "desktop_updater", binaryMessenger: messenger)
        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "restartApp":
                restartApp()
                result(nil)
            case "getPlatformVersion":
                result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
            case "getExecutablePath":
                result(Bundle.main.executablePath)
            case "getCurrentVersion":
                let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
                result(version)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func restartApp() {
        let executablePath = Bundle.main.executablePath!
        let contentsPath = Bundle.main.bundlePath + "/Contents"
        let updateFolder = contentsPath + "/update"

        do {
            try copyAndReplaceFiles(from: updateFolder, to: contentsPath)
        } catch {
            print("DesktopUpdaterPatch: error copying update files: \(error)")
            return
        }

        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executablePath)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = []
            try process.run()
        } catch {
            print("DesktopUpdaterPatch: error relaunching app: \(error)")
            return
        }

        NSApplication.shared.terminate(nil)
    }

    private static func copyAndReplaceFiles(from sourcePath: String, to destinationPath: String) throws {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: sourcePath) else { return }

        while let element = enumerator.nextObject() as? String {
            let src = (sourcePath as NSString).appendingPathComponent(element)
            let dst = (destinationPath as NSString).appendingPathComponent(element)

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: src, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                if !fileManager.fileExists(atPath: dst) {
                    try fileManager.createDirectory(atPath: dst, withIntermediateDirectories: true, attributes: nil)
                }
            } else {
                let attrs = try fileManager.attributesOfItem(atPath: src)
                if attrs[.type] as? FileAttributeType == .typeSymbolicLink {
                    if fileManager.fileExists(atPath: dst) {
                        try fileManager.removeItem(atPath: dst)
                    }
                    let target = try fileManager.destinationOfSymbolicLink(atPath: src)
                    try fileManager.createSymbolicLink(atPath: dst, withDestinationPath: target)
                } else {
                    if fileManager.fileExists(atPath: dst) {
                        try fileManager.replaceItem(at: URL(fileURLWithPath: dst),
                                                    withItemAt: URL(fileURLWithPath: src),
                                                    backupItemName: nil, options: [],
                                                    resultingItemURL: nil)
                    } else {
                        try fileManager.copyItem(atPath: src, toPath: dst)
                    }
                }
            }
        }
    }
}
