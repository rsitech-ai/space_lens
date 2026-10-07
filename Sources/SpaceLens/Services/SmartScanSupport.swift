import Foundation

public struct VolumePressure: Hashable, Sendable {
    public let volumePath: String
    public let volumeName: String
    public let totalBytes: Int64
    public let availableBytes: Int64
    public let importantAvailableBytes: Int64
    public let opportunisticAvailableBytes: Int64

    public init(
        volumePath: String,
        volumeName: String,
        totalBytes: Int64,
        availableBytes: Int64,
        importantAvailableBytes: Int64,
        opportunisticAvailableBytes: Int64
    ) {
        self.volumePath = volumePath
        self.volumeName = volumeName
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.importantAvailableBytes = importantAvailableBytes
        self.opportunisticAvailableBytes = opportunisticAvailableBytes
    }

    public var usedBytes: Int64 {
        max(0, totalBytes - importantAvailableBytes)
    }

    public var purgeableBytes: Int64 {
        max(0, importantAvailableBytes - opportunisticAvailableBytes)
    }

    public var isUnderPressure: Bool {
        importantAvailableBytes < 2_000_000_000
    }

    public var headline: String {
        let available = ByteFormat.string(opportunisticAvailableBytes > 0 ? opportunisticAvailableBytes : availableBytes)
        let important = ByteFormat.string(importantAvailableBytes)
        let used = ByteFormat.string(usedBytes)
        let total = ByteFormat.string(totalBytes)
        let pressure = isUnderPressure ? "under pressure" : "capacity"
        return "APFS \(volumeName) \(pressure): \(used) used of \(total); \(available) immediately available, \(important) including purgeable"
    }
}

enum VolumePressureReader {
    static func read(for url: URL) -> VolumePressure? {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeLocalizedNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityForOpportunisticUsageKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity
        else {
            return nil
        }

        let available = Int64(values.volumeAvailableCapacity ?? 0)
        let important = values.volumeAvailableCapacityForImportantUsage ?? available
        let opportunistic = values.volumeAvailableCapacityForOpportunisticUsage ?? available
        let name = values.volumeLocalizedName ?? values.volumeName ?? "Data"
        return VolumePressure(
            volumePath: url.resolvingSymlinksInPath().path,
            volumeName: name,
            totalBytes: Int64(total),
            availableBytes: available,
            importantAvailableBytes: important,
            opportunisticAvailableBytes: opportunistic
        )
    }
}

public struct PathUseSnapshot: Hashable, Sendable {
    public let runningToolLabels: [String]
    public let xcodeFamilyActive: Bool
    public let dockerActive: Bool
    public let cursorActive: Bool
    public let cargoActive: Bool
    public let nodePackageActive: Bool
    public let openPaths: [String]
    public let simulatorInventory: SimulatorInventory
    public let activityCheckError: String?
    private let openPathIndex: OpenPathIndex

    public static let empty = PathUseSnapshot(
        runningToolLabels: [],
        xcodeFamilyActive: false,
        dockerActive: false,
        cursorActive: false,
        cargoActive: false
    )

    public init(
        runningToolLabels: [String],
        xcodeFamilyActive: Bool,
        dockerActive: Bool,
        cursorActive: Bool,
        cargoActive: Bool,
        nodePackageActive: Bool = false,
        openPaths: [String] = [],
        simulatorInventory: SimulatorInventory = .empty,
        activityCheckError: String? = nil
    ) {
        self.runningToolLabels = runningToolLabels
        self.xcodeFamilyActive = xcodeFamilyActive
        self.dockerActive = dockerActive
        self.cursorActive = cursorActive
        self.cargoActive = cargoActive
        self.nodePackageActive = nodePackageActive
        self.openPaths = openPaths
        self.openPathIndex = OpenPathIndex(openPaths: openPaths)
        self.simulatorInventory = simulatorInventory
        self.activityCheckError = activityCheckError
    }

    func hasNewlyRunningTools(comparedTo previous: PathUseSnapshot) -> Bool {
        (xcodeFamilyActive && !previous.xcodeFamilyActive)
            || (dockerActive && !previous.dockerActive)
            || (cursorActive && !previous.cursorActive)
            || (cargoActive && !previous.cargoActive)
            || (nodePackageActive && !previous.nodePackageActive)
    }

    public func isPathOpen(_ path: String) -> Bool { openPathIndex.contains(path) }

    public func withSimulatorInventory(_ inventory: SimulatorInventory) -> PathUseSnapshot {
        PathUseSnapshot(
            runningToolLabels: runningToolLabels,
            xcodeFamilyActive: xcodeFamilyActive,
            dockerActive: dockerActive,
            cursorActive: cursorActive,
            cargoActive: cargoActive,
            nodePackageActive: nodePackageActive,
            openPaths: openPaths,
            simulatorInventory: inventory,
            activityCheckError: activityCheckError
        )
    }

    public var caveats: [String] {
        var lines: [String] = []
        if let activityCheckError { lines.append(activityCheckError) }
        if xcodeFamilyActive {
            lines.append("Xcode, Simulator, or xcodebuild is running; DerivedData, CoreSimulator, DeviceSupport, and /tmp are not cleanup-ready.")
        }
        if dockerActive {
            lines.append("Docker is running; Docker.raw / VM storage is tool-owned and not claimed as pruneable.")
        }
        if cursorActive {
            lines.append("Cursor is running; application caches may be open. User/history was not treated as cache.")
        }
        if cargoActive {
            lines.append("Cargo or rustc is running; Cargo registry, git, target, and rustup paths may be in use.")
        }
        if nodePackageActive {
            lines.append("node/npm/pnpm/yarn is running; dependency and package cache trees stay Active until those tools close.")
        }
        if let error = simulatorInventory.error {
            lines.append("simctl inventory failed: \(error)")
        }
        return lines
    }

    public func withOpenPaths(_ openPaths: [String]) -> PathUseSnapshot {
        PathUseSnapshot(
            runningToolLabels: runningToolLabels,
            xcodeFamilyActive: xcodeFamilyActive,
            dockerActive: dockerActive,
            cursorActive: cursorActive,
            cargoActive: cargoActive,
            nodePackageActive: nodePackageActive,
            openPaths: openPaths,
            simulatorInventory: simulatorInventory,
            activityCheckError: activityCheckError
        )
    }
}

enum PathUseDetector {
    static func liveSnapshot(simulatorInventory: SimulatorInventory = .empty) async -> PathUseSnapshot {
        if isRunningUnderXCTest {
            return snapshot(runningProcessNames: [], openPaths: [], simulatorInventory: simulatorInventory)
        }
        async let processes = BoundedProcess.run(executable: "/bin/ps", arguments: ["-Ao", "comm="], timeout: 2)
        async let openFiles = BoundedProcess.run(executable: "/usr/sbin/lsof", arguments: ["-nP", "-w", "-Fn", "-u", String(getuid())], timeout: 12)
        let (namesText, opensText) = await (processes, openFiles)
        let names = (namesText ?? "").split(whereSeparator: \.isNewline).map { URL(fileURLWithPath: String($0).trimmingCharacters(in: .whitespaces)).lastPathComponent }
        let result = snapshot(runningProcessNames: names, openPaths: parseLsofNameOutput(opensText ?? ""), simulatorInventory: simulatorInventory)
        return PathUseSnapshot(
            runningToolLabels: result.runningToolLabels,
            xcodeFamilyActive: result.xcodeFamilyActive,
            dockerActive: result.dockerActive,
            cursorActive: result.cursorActive,
            cargoActive: result.cargoActive,
            nodePackageActive: result.nodePackageActive,
            openPaths: result.openPaths,
            simulatorInventory: simulatorInventory,
            activityCheckError: namesText == nil || opensText == nil ? "Activity check unavailable or timed out. Cleanup stays disabled; close tools and rescan." : nil
        )
    }

    static func snapshot(
        runningProcessNames: [String],
        openPaths: [String] = [],
        simulatorInventory: SimulatorInventory = .empty
    ) -> PathUseSnapshot {
        let names = runningProcessNames.map { $0.lowercased() }
        let opens = openPaths.filter { !isTooBroadOpenPath($0) }
        let labels = names.filter { name in
            xcodeTokens.contains(where: { name.contains($0) })
                || dockerTokens.contains(where: { name.contains($0) })
                || cursorTokens.contains(where: { name.contains($0) })
                || cargoTokens.contains(where: { name.contains($0) })
                || nodeTokens.contains(where: { name.contains($0) })
        }
        return PathUseSnapshot(
            runningToolLabels: Array(Set(labels)).sorted(),
            xcodeFamilyActive: names.contains { name in xcodeTokens.contains { name.contains($0) } },
            dockerActive: names.contains { name in dockerTokens.contains { name.contains($0) } },
            cursorActive: names.contains { name in cursorTokens.contains { name.contains($0) } },
            cargoActive: names.contains { name in cargoTokens.contains { name.contains($0) } },
            nodePackageActive: names.contains { name in nodeTokens.contains { name.contains($0) } },
            openPaths: opens,
            simulatorInventory: simulatorInventory
        )
    }

    static func parseLsofNameOutput(_ text: String) -> [String] {
        var paths: [String] = []
        var seen: Set<String> = []
        for line in text.split(whereSeparator: \.isNewline) {
            guard line.first == "n" else {
                continue
            }
            let path = String(line.dropFirst())
            guard path.hasPrefix("/"), seen.insert(path).inserted else {
                continue
            }
            paths.append(path)
        }
        return paths
    }

    static func pathIsOpen(_ path: String, openPaths: [String]) -> Bool {
        OpenPathIndex(openPaths: openPaths).contains(path)
    }

    static func normalizedActivityPath(_ path: String) -> String {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        if normalized.hasPrefix("/System/Volumes/Data/") { return String(normalized.dropFirst("/System/Volumes/Data".count)) }
        if normalized == "/tmp" || normalized.hasPrefix("/tmp/") { return "/private" + normalized }
        if normalized == "/var" || normalized.hasPrefix("/var/") { return "/private" + normalized }
        return normalized
    }

    static func isTooBroadOpenPath(_ path: String) -> Bool {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path.lowercased()
        if normalized == "/" || normalized == "/system/volumes/data" {
            return true
        }
        let parts = normalized.split(separator: "/").map(String.init)
        if parts == ["users"] || (parts.count == 2 && parts[0] == "users") {
            return true
        }
        return (parts.count == 4 || parts.count == 5)
            && parts.starts(with: ["system", "volumes", "data", "users"])
    }

    static func matchingOpenPaths(candidatePaths: [String], openPaths: [String]) -> [String] {
        let candidates = Set(candidatePaths.map(normalizedActivityPath))
        return openPaths.filter { open in
            guard !isTooBroadOpenPath(open) else { return false }
            var path = normalizedActivityPath(open)
            while !path.isEmpty && path != "/" {
                if candidates.contains(path) { return true }
                path = (path as NSString).deletingLastPathComponent
            }
            return false
        }
    }

    static func mappedHitCount(candidatePaths: [String], openPaths: [String]) -> Int {
        let index = OpenPathIndex(openPaths: openPaths)
        return candidatePaths.reduce(0) { $0 + (index.contains($1) ? 1 : 0) }
    }

    private static var isRunningUnderXCTest: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
            || ProcessInfo.processInfo.arguments.contains { $0.contains("xctest") }
    }

    private static let xcodeTokens = [
        "xcode",
        "xcodebuild",
        "ibtoold",
        "ibagent",
        "sourcekitservice",
        "swift",
        "coresimulator",
        "simulator"
    ]

    private static let dockerTokens = ["com.docker", "dockerd", "docker"]

    private static let cursorTokens = ["cursor helper", "cursor"]

    private static let cargoTokens = ["cargo", "rustc"]

    private static let nodeTokens = ["node", "npm", "pnpm", "yarn"]
}

private struct OpenPathIndex: Hashable, Sendable {
    private let ancestors: Set<String>

    init(openPaths: [String]) {
        var paths: Set<String> = []
        for open in openPaths where !PathUseDetector.isTooBroadOpenPath(open) {
            var path = PathUseDetector.normalizedActivityPath(open)
            while !path.isEmpty && path != "/" {
                if !paths.insert(path).inserted { break }
                path = (path as NSString).deletingLastPathComponent
            }
        }
        ancestors = paths
    }

    func contains(_ path: String) -> Bool {
        !PathUseDetector.isTooBroadOpenPath(path) && ancestors.contains(PathUseDetector.normalizedActivityPath(path))
    }
}

enum BoundedProcess {
    static func run(executable: String, arguments: [String], timeout: TimeInterval) -> String? {
        Session().run(executable: executable, arguments: arguments, timeout: timeout)
    }

    static func run(executable: String, arguments: [String], timeout: TimeInterval) async -> String? {
        let session = Session()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    continuation.resume(returning: session.run(
                        executable: executable,
                        arguments: arguments,
                        timeout: timeout
                    ))
                }
            }
        } onCancel: {
            session.terminate()
        }
    }

    private final class Session: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var cancelled = false

        func terminate() {
            lock.lock()
            defer { lock.unlock() }
            cancelled = true
            if let process, process.isRunning { process.terminate() }
        }

        func run(executable: String, arguments: [String], timeout: TimeInterval) -> String? {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            lock.lock()
            let cancelled = self.cancelled
            if cancelled {
                lock.unlock()
                return nil
            }

            do {
                try process.run()
                self.process = process
                lock.unlock()
            } catch {
                lock.unlock()
                return nil
            }

            let watchdog = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
            watchdog.schedule(deadline: .now() + timeout)
            watchdog.setEventHandler { [self, process] in
                terminate()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.25) { [process] in
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
            }
            watchdog.resume()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            watchdog.cancel()
            guard process.terminationStatus == 0 else { return nil }
            lock.lock()
            let wasCancelled = self.cancelled
            lock.unlock()
            return wasCancelled ? nil : String(data: data, encoding: .utf8)
        }
    }
}

public struct SimulatorDevice: Hashable, Sendable {
    public let udid: String
    public let name: String
    public let runtime: String
    public let state: String
    public let isAvailable: Bool
    public let dataPath: String

    public var isBooted: Bool {
        state.caseInsensitiveCompare("Booted") == .orderedSame
    }

    public var displayName: String {
        "Simulator: \(name) (\(state))"
    }
}

public struct SimulatorInventory: Hashable, Sendable {
    public let devices: [SimulatorDevice]
    public let error: String?

    public static let empty = SimulatorInventory(devices: [], error: nil)

    public init(devices: [SimulatorDevice], error: String? = nil) {
        self.devices = devices
        self.error = error
    }

    public func device(matching path: String) -> SimulatorDevice? {
        let needle = PathUseDetector.normalizedActivityPath(path)
        return devices.first { device in
            let data = PathUseDetector.normalizedActivityPath(device.dataPath)
            guard !data.isEmpty else {
                return false
            }
            return needle == data || needle.hasPrefix(data.hasSuffix("/") ? data : data + "/")
                || data.hasPrefix(needle.hasSuffix("/") ? needle : needle + "/")
                || needle.contains("/coresimulator/devices/\(device.udid.lowercased())")
        }
    }

    public static func parse(json data: Data) throws -> SimulatorInventory {
        let decoded = try JSONDecoder().decode(SimctlList.self, from: data)
        let devices = decoded.devices.flatMap { runtime, rows in
            rows.map { row in
                SimulatorDevice(
                    udid: row.udid,
                    name: row.name,
                    runtime: runtime,
                    state: row.state,
                    isAvailable: row.isAvailable ?? true,
                    dataPath: row.dataPath ?? ""
                )
            }
        }
        return SimulatorInventory(devices: devices)
    }

    public static func load(run: (() throws -> Data)? = nil) -> SimulatorInventory {
        do {
            let data = try (run ?? defaultSimctlJSON)()
            return try parse(json: data)
        } catch {
            return SimulatorInventory(devices: [], error: error.localizedDescription)
        }
    }

    public static func loadCancellable() async -> SimulatorInventory {
        do {
            guard let text = await BoundedProcess.run(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "list", "devices", "-j"],
                timeout: 8
            ), let data = text.data(using: .utf8), !data.isEmpty else {
                throw SimctlError.unavailable
            }
            return try parse(json: data)
        } catch {
            return SimulatorInventory(devices: [], error: error.localizedDescription)
        }
    }

    private static func defaultSimctlJSON() throws -> Data {
        guard let text = BoundedProcess.run(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "list", "devices", "-j"],
            timeout: 8
        ), let data = text.data(using: .utf8), !data.isEmpty else {
            throw SimctlError.unavailable
        }
        return data
    }

    private enum SimctlError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "xcrun simctl list devices failed or timed out"
        }
    }
}

private struct SimctlList: Decodable {
    let devices: [String: [SimctlDevice]]
}

private struct SimctlDevice: Decodable {
    let udid: String
    let name: String
    let state: String
    let isAvailable: Bool?
    let dataPath: String?
}

enum SmartScanCatalog {
    static let homeTemplates: [(template: String, displayName: String)] = [
        ("~/Library/Developer/Xcode/DerivedData", "Xcode DerivedData"),
        ("~/Library/Developer/Xcode/iOS DeviceSupport", "Xcode iOS DeviceSupport"),
        ("~/Library/Developer/Xcode/watchOS DeviceSupport", "Xcode watchOS DeviceSupport"),
        ("~/Library/Developer/Xcode/tvOS DeviceSupport", "Xcode tvOS DeviceSupport"),
        ("~/Library/Developer/Xcode/DocumentationCache", "Xcode Documentation Cache"),
        ("~/Library/Developer/Xcode/Archives", "Xcode Archives"),
        ("~/Library/Developer/CoreSimulator/Caches", "Xcode Simulator Caches"),
        ("~/Library/Developer/CoreSimulator/Devices", "Xcode Simulator Devices"),
        ("~/Library/Developer/XCTestDevices", "XCTest Devices"),
        ("~/.gradle/caches", "Gradle Caches"),
        ("~/anaconda3/pkgs", "Conda Package Cache"),
        ("~/miniconda3/pkgs", "Conda Package Cache"),
        ("~/.npm", "npm Cache"),
        ("~/Library/pnpm/store", "pnpm Store"),
        ("~/.local/share/pnpm/store", "pnpm Store"),
        ("~/Library/Caches/Yarn", "Yarn Cache"),
        ("~/.yarn/berry/cache", "Yarn Berry Cache"),
        ("~/.cargo/registry", "Cargo Registry"),
        ("~/.cargo/git", "Cargo Git Cache"),
        ("~/.m2/repository", "Maven Repository"),
        ("~/Library/Caches/Homebrew", "Homebrew Cache"),
        ("~/Library/Caches/CocoaPods", "CocoaPods Cache"),
        ("~/Library/Caches/pip", "pip Cache"),
        ("~/Library/Caches/ms-playwright", "Playwright Browsers"),
        ("~/.cache/puppeteer", "Puppeteer Cache"),
        ("~/.cache/ms-playwright", "Playwright Cache"),
        ("~/.cache/uv", "uv Cache"),
        ("~/.cache/pip", "pip Cache"),
        ("~/.composer/cache", "Composer Cache"),
        ("~/.bun/install/cache", "bun Cache"),
        ("~/go/pkg/mod", "Go Module Cache"),
        ("~/Library/Caches/go-build", "Go Build Cache"),
        ("~/.rustup/toolchains", "Rust Toolchains"),
        ("~/.codex/sessions", "Codex Sessions"),
        ("~/.codex/worktrees", "Codex Worktrees"),
        ("~/.codex/tmp", "Codex Temporary Files"),
        ("~/Library/Application Support/Cursor/Cache", "Cursor Cache"),
        ("~/Library/Application Support/Cursor/CachedData", "Cursor CachedData"),
        ("~/Library/Application Support/Cursor/CachedExtensionVSIXs", "Cursor VSIX Cache"),
        ("~/Library/Application Support/Cursor/Code Cache", "Cursor Code Cache"),
        ("~/Library/Application Support/Cursor/GPUCache", "Cursor GPU Cache"),
        ("~/Library/Application Support/Cursor/DawnGraphiteCache", "Cursor Dawn Graphite Cache"),
        ("~/Library/Application Support/Cursor/DawnWebGPUCache", "Cursor Dawn WebGPU Cache"),
        ("~/Library/Application Support/Cursor/ShaderCache", "Cursor Shader Cache"),
        ("~/Library/Application Support/Cursor/logs", "Cursor Logs"),
        ("~/Library/Application Support/Cursor/Partitions", "Cursor Partitions"),
        ("~/Library/Application Support/Cursor/WebStorage", "Cursor WebStorage"),
        ("~/Library/Application Support/Cursor/User", "Cursor User Data"),
        ("~/Library/Application Support/Code/Cache", "VS Code Cache"),
        ("~/Library/Application Support/Code/CachedData", "VS Code CachedData"),
        ("~/Library/Application Support/MobileSync/Backup", "iOS Backups"),
        ("~/Library/Mail Downloads", "Mail Downloads"),
        ("~/Library/Containers/com.docker.docker/Data/vms", "Docker VM Storage"),
        ("~/.Trash", "Trash"),
        ("~/.cache/huggingface", "Hugging Face Models"),
        ("~/.lmstudio/models", "LM Studio Models"),
        ("~/.ollama/models", "Ollama Models"),
        ("~/.android/avd", "Android Emulator Devices")
    ]

    static let volumeWideTemplates: [(template: String, displayName: String)] = [
        ("/private/tmp", "Temporary Files (/private/tmp)"),
        ("/Library/Developer/CoreSimulator/Caches", "Xcode Simulator Caches"),
        ("/Library/Developer/CoreSimulator/Devices", "Xcode Simulator Devices")
    ]

    static let priorityHomeRelativePaths = [
        "dev",
        "Projects",
        "src",
        "code",
        "workspace",
        "Library/Caches",
        "Library/Developer"
    ]

    static let userContentRootNames: Set<String> = [
        "documents",
        "desktop",
        "downloads",
        "movies",
        "pictures",
        "music"
    ]

    static let largeUserContentByteThreshold: Int64 = 16_000_000
    static let documentsInventoryLimit = 20
    static let discoveredDirectoryNames: Set<String> = [
        ".build",
        ".next",
        ".nuxt",
        ".svelte-kit",
        ".parcel-cache",
        ".turbo",
        ".dart_tool",
        ".pytest_cache",
        ".mypy_cache",
        ".ruff_cache",
        "deriveddata",
        "__pycache__",
        ".venv",
        "venv",
        "buck-out",
        "bazel-out",
        ".bazel-cache"
    ]

    static func extraSystemRoots(
        scanRoot: URL,
        homeDirectory: URL,
        realHomeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        let scan = scanRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let home = homeDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let realHome = realHomeDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let isVolumeWide = scan == "/"
        let isRealHomeScan = home == realHome && isVolumeWide
        guard isRealHomeScan else {
            return []
        }
        return volumeWideTemplates.map { URL(fileURLWithPath: $0.template).standardizedFileURL }
    }

    static func isProjectDerivedDataName(_ name: String) -> Bool {
        name == "deriveddata" || name.hasPrefix("deriveddata-")
    }

    // Delay likely large roots so smaller candidates appear sooner.
    static func collapsedMeasureRank(_ url: URL) -> Int {
        let name = url.lastPathComponent.lowercased()
        if isProjectDerivedDataName(name)
            || name == "node_modules"
            || name == "target"
            || name == ".build"
            || name == "devices"
            || name == "intermediates"
            || name == "tmp" {
            return 2
        }
        let path = url.path.lowercased()
        if path.contains("/deriveddata")
            || path.contains("/coresimulator/devices")
            || path.contains("/node_modules")
            || path.hasSuffix("/target")
            || path.contains("/.build/")
            || path.hasSuffix("/.build") {
            return 2
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            return 0
        }
        return 1
    }

    static func isUserContentPath(_ path: String) -> Bool {
        let lowered = path.lowercased()
        return userContentRootNames.contains { name in
            lowered.contains("/\(name)/") || lowered.hasSuffix("/\(name)")
        }
    }

    static func isCoreSimulatorDevicesTemplate(_ template: String) -> Bool {
        template.lowercased().hasSuffix("/coresimulator/devices")
    }

    static func displayName(for url: URL) -> String? {
        let path = url.standardizedFileURL.path.lowercased()
        let name = url.lastPathComponent.lowercased()
        for entry in homeTemplates + volumeWideTemplates where path.hasSuffix(suffix(for: entry.template)) {
            return entry.displayName
        }
        if name == "node_modules" || path.hasSuffix("/node_modules") {
            return "Node Modules"
        }
        if path.hasSuffix("/node_modules/.cache") {
            return "Node Package Cache"
        }
        switch name {
        case ".build":
            return "Build Artifacts (.build)"
        case "target":
            return "Cargo Artifacts (target)"
        case "intermediates":
            return "Android Build Intermediates"
        case ".dart_tool":
            return "Dart Tool Cache"
        case ".pytest_cache":
            return "Pytest Cache"
        case ".mypy_cache":
            return "Mypy Cache"
        case ".ruff_cache":
            return "Ruff Cache"
        case "__pycache__":
            return "Python Bytecode Cache"
        case ".venv", "venv":
            return "Python Virtualenv"
        case "buck-out":
            return "Buck Build Output"
        case "bazel-out", ".bazel-cache":
            return "Bazel Build Output"
        case "output":
            return "Research Output"
        default:
            return nil
        }
    }

    private static func suffix(for template: String) -> String {
        if template.hasPrefix("~/") {
            return "/" + String(template.dropFirst(2)).lowercased()
        }
        return template.lowercased()
    }
}

public struct ScanSummaryContext: Hashable, Sendable {
    public var volumePressure: VolumePressure?
    public var pathUse: PathUseSnapshot
    public var didRemoveFiles: Bool
    public var pendingDiscoveryPaths: [String]

    public static let empty = ScanSummaryContext()

    public init(
        volumePressure: VolumePressure? = nil,
        pathUse: PathUseSnapshot = .empty,
        didRemoveFiles: Bool = false,
        pendingDiscoveryPaths: [String] = []
    ) {
        self.volumePressure = volumePressure
        self.pathUse = pathUse
        self.didRemoveFiles = didRemoveFiles
        self.pendingDiscoveryPaths = pendingDiscoveryPaths
    }
}

// Scoped to one cleanup batch. Manual moves always force a fresh probe after folder
// inspection; short automatic batches reuse a snapshot for at most two seconds.
actor CleanupActivityRefresh {
    private var cached: PathUseSnapshot
    private var checkedAt = ContinuousClock.now
    private let provider: @Sendable () async -> PathUseSnapshot

    init(initial: PathUseSnapshot, provider: @escaping @Sendable () async -> PathUseSnapshot) {
        cached = initial
        self.provider = provider
    }

    func snapshot(forceRefresh: Bool) async -> PathUseSnapshot {
        if forceRefresh || checkedAt.duration(to: .now) >= .seconds(2) {
            cached = await provider()
            checkedAt = .now
        }
        return cached
    }
}
