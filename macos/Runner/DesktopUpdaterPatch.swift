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
                if let error = restartApp() {
                    result(FlutterError(code: "RESTART_FAILED", message: error, details: nil))
                } else {
                    result(nil)
                }
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

    // Returns nil on success, or an error message string on failure.
    //
    // We use a detached shell script rather than copying files inline, because:
    // - replaceItem/rename on paths that go through framework symlinks
    //   (e.g. Versions/Current/) can fail while the app bundle is live.
    // - cp -rf handles symlink-traversal naturally on macOS.
    // The script runs after the app exits (reparented to init), copies the
    // update folder over Contents/, cleans up, then relaunches via 'open'.
    private static func restartApp() -> String? {
        let bundlePath = Bundle.main.bundlePath
        let contentsPath = bundlePath + "/Contents"
        let updateFolder = contentsPath + "/update"

        let script = """
        #!/bin/sh
        sleep 1
        if [ -d "\(updateFolder)" ]; then
            cp -rf "\(updateFolder)/." "\(contentsPath)/"
            rm -rf "\(updateFolder)"
        fi
        open "\(bundlePath)"
        """

        let tmpScript: String
        do {
            let tmpDir = try FileManager.default.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: URL(fileURLWithPath: bundlePath),
                create: true
            )
            let scriptURL = tmpDir.appendingPathComponent("shackleton_update.sh")
            tmpScript = scriptURL.path
            try script.write(toFile: tmpScript, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpScript)
        } catch {
            return "failed to write update script: \(error)"
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [tmpScript]

        do {
            try process.run()
        } catch {
            return "failed to launch update script: \(error)"
        }

        NSApplication.shared.terminate(nil)
        return nil
    }

}
