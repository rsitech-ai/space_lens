import Foundation

public struct RuleEngine: Sendable {
    private let userLibraryCachesPath: String

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        userLibraryCachesPath = homeDirectory
            .appendingPathComponent("Library/Caches", isDirectory: true)
            .standardizedFileURL
            .path
            .lowercased()
    }

    public func classify(_ node: FileNode, pathUse: PathUseSnapshot = .empty) -> SafetyClassification {
        overlayProcessUse(classifyPath(node), node: node, pathUse: pathUse)
    }

    private func classifyPath(_ node: FileNode) -> SafetyClassification {
        let path = node.path.lowercased()
        let name = node.url.lastPathComponent.lowercased()
        let pathComponents = node.url.pathComponents.map { $0.lowercased() }
        let fileExtension = node.url.pathExtension.lowercased()

        if node.isSymlink {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.99,
                category: "Symbolic link",
                summary: "SpaceLens does not offer symbolic links for cleanup.",
                evidence: ["The scanned item is a symbolic link.", "Its destination may differ from the visible path."],
                recommendedAction: "Reveal and inspect the link manually."
            )
        }

        if let scanError = node.scanError {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.99,
                category: "Incomplete scan",
                summary: "SpaceLens could not inspect this item completely.",
                evidence: ["The scan reported an error: \(scanError)"],
                recommendedAction: "Resolve the access or filesystem error, then rescan before cleanup."
            )
        }

        if isSystemCritical(path: path) {
            return SafetyClassification(
                level: .systemCritical,
                confidence: 0.98,
                category: "System/private data",
                summary: "This is inside a protected macOS location.",
                evidence: ["Path is under a protected system/private directory.", "SpaceLens never recommends raw cleanup here."],
                recommendedAction: "Do not delete from SpaceLens.",
                kind: .unknownLarge
            )
        }

        if isSystemVirtualMemory(path: path) {
            return SafetyClassification(
                level: .systemCritical,
                confidence: 0.99,
                category: "macOS virtual memory",
                summary: "This is macOS swap or virtual memory state.",
                evidence: ["Matched /System/Volumes/VM.", "Manual deletion can destabilize macOS."],
                recommendedAction: "Do not delete manually. Close heavy apps or reboot if swap is high.",
                kind: .unknownLarge
            )
        }

        if isDockerStorage(path: path, name: name) {
            return SafetyClassification(
                level: .activeOrInUse,
                confidence: 0.96,
                category: "Docker storage",
                summary: "This appears to be Docker-owned VM, image, or volume storage.",
                evidence: [
                    "Matched Docker Desktop storage path, Docker.raw, or Docker.qcow2.",
                    "Allocated size is not proven pruneable; images and volumes are user data until Docker prune reports reclaim."
                ],
                recommendedAction: "Use Docker's own prune/compact tools if you intend to reclaim space, then rescan. Do not delete Docker.raw by hand.",
                kind: .docker
            )
        }

        if isAppleWallpaperAerials(path: path) {
            return SafetyClassification(
                level: .safeTemp,
                confidence: 0.92,
                category: ScanKind.temp.displayName,
                summary: "These are downloaded Apple aerial wallpaper videos.",
                evidence: ["Matched the Apple wallpaper aerial video cache.", "macOS can redownload wallpapers later."],
                recommendedAction: "Queue for review, then move to the Bin if you do not use these wallpapers.",
                kind: .temp
            )
        }

        if isCoreSimulatorCache(path: path) {
            return SafetyClassification(
                level: .rebuildableCache,
                confidence: 0.94,
                category: ScanKind.simulator.displayName,
                summary: "This is Xcode Simulator cache data, not a device runtime.",
                evidence: ["Matched CoreSimulator cache storage.", "Xcode and Simulator can rebuild cache files."],
                recommendedAction: "Queue for review; close Simulator and Xcode before cleanup.",
                kind: .rebuildableCache
            )
        }

        if isSimulatorRuntime(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.88,
                category: ScanKind.simulator.displayName,
                summary: "This is simulator or XCTest device state, not a disposable cache.",
                evidence: [
                    "Matched CoreSimulator Devices or XCTestDevices.",
                    "Usable and in-use simulators should not be auto-deleted."
                ],
                recommendedAction: "Keep available/in-use devices. Remove only unavailable devices from Xcode or simctl after review.",
                kind: .simulator
            )
        }

        if isXcodeArchives(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.86,
                category: "Xcode archives",
                summary: "These are Xcode archives and may be release artifacts you still need.",
                evidence: ["Matched Xcode Archives.", "Archives are user-built products, not a routine cache."],
                recommendedAction: "Keep App Store and release archives. Delete only obsolete archives you can rebuild.",
                kind: .unknownLarge
            )
        }

        if isAndroidEmulatorDevice(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.82,
                category: "Android emulator device",
                summary: "This looks like an Android virtual device image.",
                evidence: ["Matched an .android/avd device path.", "Deleting it removes that emulator device state."],
                recommendedAction: "Reveal and delete only if you do not need this emulator.",
                kind: .simulator
            )
        }

        if isRustToolchainStore(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.82,
                category: ScanKind.toolchain.displayName,
                summary: "This stores installed Rust toolchains.",
                evidence: [
                    "Matched rustup toolchain storage.",
                    "Pinned/active toolchains are required; extra unused toolchains can be removed with rustup."
                ],
                recommendedAction: "Use rustup toolchain list and remove only extra unused toolchains. Do not delete the active default.",
                kind: .toolchain
            )
        }

        if isPythonVirtualenv(name: name, components: pathComponents) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.8,
                category: ScanKind.toolchain.displayName,
                summary: "This looks like a Python virtual environment.",
                evidence: ["Matched .venv or venv.", "It is regenerable from a lockfile, but deleting it breaks the current environment."],
                recommendedAction: "Recreate with the project tool if unused. Do not auto-delete active environments.",
                kind: .toolchain
            )
        }

        if isCondaPackageCache(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.86,
                category: ScanKind.packageCache.displayName,
                summary: "This is Conda package cache data.",
                evidence: ["Matched anaconda3/pkgs or miniconda3/pkgs.", "Conda has its own cleanup tooling."],
                recommendedAction: "Prefer conda clean before raw deletion.",
                kind: .packageCache
            )
        }

        if isCodexUserData(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.8,
                category: ScanKind.userHistory.displayName,
                summary: "These are local Codex sessions or worktrees, not routine cache.",
                evidence: ["Matched .codex/sessions or .codex/worktrees.", "They can contain useful history and checkout state."],
                recommendedAction: "Review retention needs before deleting old sessions or worktrees.",
                kind: .userHistory
            )
        }

        if isNotionLocalState(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.78,
                category: "Notion local state",
                summary: "This appears to be Notion local cache or synced state.",
                evidence: ["Matched Notion Partitions storage.", "Notion may need to re-sync after cleanup."],
                recommendedAction: "Close Notion and review before cleanup.",
                kind: .userHistory
            )
        }

        if isCursorUserData(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.8,
                category: ScanKind.userHistory.displayName,
                summary: "This is Cursor User data, including history and global storage.",
                evidence: ["Matched Cursor User storage.", "This is local history and extension state, not application cache."],
                recommendedAction: "Review inside Cursor before deleting local history or global storage.",
                kind: .userHistory
            )
        }

        if isCursorApplicationCache(path: path) {
            return SafetyClassification(
                level: .rebuildableCache,
                confidence: 0.84,
                category: ScanKind.rebuildableCache.displayName,
                summary: "This is a Cursor application cache, not User data.",
                evidence: ["Matched Cursor CachedData, Cache, VSIX, or logs.", "Cursor User/history was excluded."],
                recommendedAction: "Close Cursor first, then queue for review if you can tolerate a cold start.",
                kind: .rebuildableCache
            )
        }

        if isResearchDataCache(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.84,
                category: "Research data cache",
                summary: "This looks generated, but it belongs to a research project.",
                evidence: ["Matched a research data cache or backtest output path.", "Large generated data may still be needed for reproducibility."],
                recommendedAction: "Archive or delete only after confirming the run/data is reproducible or obsolete.",
                kind: .researchData
            )
        }

        if isDownloadedResearchLibrary(path: path) {
            return SafetyClassification(
                level: .largeButValuable,
                confidence: 0.9,
                category: "Research corpus",
                summary: "This looks like a downloaded research/library corpus.",
                evidence: ["Matched a downloaded research library path.", "The content is user/project data, not a disposable cache."],
                recommendedAction: "Do not delete unless you explicitly decide this corpus is disposable.",
                kind: .researchData
            )
        }

        if isAIModelStore(path: path) {
            return SafetyClassification(
                level: .largeButValuable,
                confidence: 0.92,
                category: "AI models",
                summary: "This looks like a locally installed model store.",
                evidence: ["Matched known local model cache path.", "Models are large but user-managed assets."],
                recommendedAction: "Review manually before removing any model.",
                kind: .unknownLarge
            )
        }

        if isIOSBackup(path: path) {
            return SafetyClassification(
                level: .largeButValuable,
                confidence: 0.93,
                category: "iOS backups",
                summary: "This looks like an iOS device backup.",
                evidence: ["Matched MobileSync Backup.", "Backups are user data, not cache."],
                recommendedAction: "Delete only from Finder or iTunes/Device backups UI after you have another copy.",
                kind: .unknownLarge
            )
        }

        if isMailDownloads(path: path) {
            return SafetyClassification(
                level: .largeButValuable,
                confidence: 0.86,
                category: "Mail downloads",
                summary: "This looks like Mail attachment downloads.",
                evidence: ["Matched Mail Downloads.", "These are user files unless you confirm they are disposable copies."],
                recommendedAction: "Review the largest attachments; do not treat Mail Downloads as cache.",
                kind: .unknownLarge
            )
        }

        if isTrash(path: path, name: name) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.9,
                category: ScanKind.temp.displayName,
                summary: "This is the user Trash folder.",
                evidence: ["Matched ~/.Trash.", "Items are already in Trash; SpaceLens will not empty it automatically."],
                recommendedAction: "Empty Trash in Finder if you intend to reclaim this space.",
                kind: .temp
            )
        }

        if path == "/tmp" || path == "/private/tmp" {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.99,
                category: ScanKind.temp.displayName,
                summary: "This shared temporary directory must not be removed wholesale.",
                evidence: ["Matched /tmp or /private/tmp.", "Any running app may depend on temporary files, sockets, or locks here."],
                recommendedAction: "Inspect individual stale files; never move the shared temporary directory to the Bin.",
                kind: .temp
            )
        }

        if isApplicationSupportDatabase(path: path, fileExtension: fileExtension) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.9,
                category: "App state database",
                summary: "This appears to be application state, not a disposable cache.",
                evidence: ["Located under Library/Application Support.", "Database-like extension: .\(fileExtension)."],
                recommendedAction: "Review in the owning app before deleting.",
                kind: .userHistory
            )
        }

        if pathComponents.contains("node_modules"), !path.contains("/node_modules/.cache") {
            return SafetyClassification(
                level: node.rebuildEvidence.contains(.packageLockfile) ? .rebuildableCache : .unknownReview,
                confidence: 0.86,
                category: ScanKind.packageCache.displayName,
                summary: "This is a project node_modules tree that package managers can regenerate.",
                evidence: [
                    "Matched a node_modules directory, not user documents.",
                    node.rebuildEvidence.contains(.packageLockfile) ? "A sibling package manifest and lockfile were found." : "No verified sibling package manifest and lockfile were found."
                ],
                recommendedAction: "Queue only if a lockfile exists and lsof does not show node/npm/pnpm/yarn in this tree.",
                kind: .packageCache
            )
        }

        if name == "target" {
            return SafetyClassification(
                level: node.rebuildEvidence.contains(.cargoManifest) ? .rebuildableCache : .unknownReview,
                confidence: 0.88,
                category: ScanKind.rebuildableCache.displayName,
                summary: "This looks like a Cargo target directory that can be rebuilt.",
                evidence: ["Matched a target directory.", node.rebuildEvidence.contains(.cargoManifest) ? "A sibling Cargo.toml was found." : "No sibling Cargo.toml was verified."],
                recommendedAction: "Queue only if a sibling Cargo.toml exists and no cargo/rustc process is running.",
                kind: .rebuildableCache
            )
        }

        if isAndroidBuildIntermediates(path: path, name: name) {
            return SafetyClassification(
                level: node.rebuildEvidence.contains(.gradleManifest) ? .rebuildableCache : .unknownReview,
                confidence: 0.9,
                category: ScanKind.rebuildableCache.displayName,
                summary: "This looks like Android/Gradle build intermediates.",
                evidence: ["Matched build/intermediates.", "The next Gradle build can regenerate it."],
                recommendedAction: "Queue for review after Gradle/Android Studio is idle.",
                kind: .rebuildableCache
            )
        }

        if [".next", ".nuxt", ".svelte-kit", ".parcel-cache", ".turbo"].contains(name) {
            return SafetyClassification(level: node.rebuildEvidence.contains(.packageLockfile) ? .rebuildableCache : .unknownReview,
                confidence: 0.9, category: "Web build cache", summary: "This is a conventional web build cache or generated framework output.",
                evidence: ["Matched \(name).", node.rebuildEvidence.contains(.packageLockfile) ? "A sibling package manifest and lockfile were found." : "No verified package manifest and lockfile were found."],
                recommendedAction: "Close web build tools, review the path, then rebuild from the project lockfile after cleanup.", kind: .rebuildableCache)
        }

        if isPackageCache(path: path, name: name, components: pathComponents) {
            let kind = packageCacheKind(path: path, name: name)
            return SafetyClassification(
                level: .rebuildableCache,
                confidence: 0.9,
                category: kind.displayName,
                summary: "This is a cache that tools can usually rebuild.",
                evidence: ["Matched known cache/build directory.", "Deleting may slow the next build or package install."],
                recommendedAction: "Queue for review; use Trash only after checking the project is inactive.",
                kind: kind
            )
        }

        if isCrashDump(path: path, fileExtension: fileExtension) {
            let isTemp = isTemporaryLocation(path: path)
            return SafetyClassification(
                level: isTemp ? .safeTemp : .unknownReview,
                confidence: isTemp ? 0.86 : 0.68,
                category: "Crash dumps",
                summary: isTemp ? "This looks like a disposable crash dump." : "This looks like a crash dump outside a known temp area.",
                evidence: ["Matched crash/dump file type.", isTemp ? "Located in a temp/cache-style path." : "Location is not known-safe."],
                recommendedAction: isTemp ? "Queue for review before Trash." : "Inspect before deletion.",
                kind: isTemp ? .temp : .unknownLarge
            )
        }

        if isLogFile(path: path, name: name, fileExtension: fileExtension) {
            let old = isOlderThan(days: 14, date: node.modifiedAt)
            let isDisposable = old && isTemporaryLocation(path: path)
            return SafetyClassification(
                level: isDisposable ? .safeTemp : .unknownReview,
                confidence: isDisposable ? 0.78 : 0.68,
                category: "Logs",
                summary: isDisposable
                    ? "This appears to be an old log in a disposable location."
                    : "This log may be recent, active, or valuable user data.",
                evidence: [
                    "Matched log naming pattern.",
                    old ? "Last modified more than 14 days ago." : "Recent logs may still be useful or active.",
                    isTemporaryLocation(path: path) ? "Located in a temp/cache-style path." : "Location is not known-safe."
                ],
                recommendedAction: isDisposable
                    ? "Queue for review before Trash."
                    : "Reveal and confirm the log is disposable before deleting it manually.",
                kind: .temp
            )
        }

        if isProjectOrUserData(path: path) {
            return SafetyClassification(
                level: .largeButValuable,
                confidence: 0.74,
                category: "Project/user data",
                summary: "This is in a user project or document area.",
                evidence: ["Matched user workspace or document path.", "SpaceLens treats source, datasets, and documents as valuable by default."],
                recommendedAction: "Review manually; do not treat as disposable.",
                kind: .unknownLarge
            )
        }

        if node.effectiveSize >= 1_000_000_000 {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.65,
                category: ScanKind.unknownLarge.displayName,
                summary: "This is large, but SpaceLens does not have a safe cleanup rule for it.",
                evidence: ["Size is at least 1 GB.", "No deterministic safe rule matched."],
                recommendedAction: "Inspect ownership and purpose before taking action.",
                kind: .unknownLarge
            )
        }

        return SafetyClassification(
            level: .unknownReview,
            confidence: 0.5,
            category: "Unknown",
            summary: "No safe cleanup rule matched this item.",
            evidence: ["No known cache, temp, build, or tool-owned pattern matched."],
            recommendedAction: "Review only.",
            kind: .unknownLarge
        )
    }

    private func overlayProcessUse(
        _ classification: SafetyClassification,
        node: FileNode,
        pathUse: PathUseSnapshot
    ) -> SafetyClassification {
        if let error = pathUse.activityCheckError, classification.level.isQueueable {
            return SafetyClassification(level: .unknownReview, confidence: 0.99, category: classification.category,
                summary: "SpaceLens could not verify running tools and open files.", evidence: classification.evidence + [error],
                recommendedAction: "Close tools and rescan after the activity check is available.", kind: classification.kind)
        }
        if let device = pathUse.simulatorInventory.device(matching: node.path) {
            if device.isBooted {
                return SafetyClassification(
                    level: .activeOrInUse,
                    confidence: 0.95,
                    category: ScanKind.simulator.displayName,
                    summary: "Simulator \(device.name) is Booted.",
                    evidence: classification.evidence + ["simctl state: Booted.", "udid \(device.udid)."],
                    recommendedAction: "Shut down the simulator before considering cleanup.",
                    kind: .simulator
                )
            }
            if !device.isAvailable {
                return SafetyClassification(
                    level: .unknownReview,
                    confidence: 0.9,
                    category: ScanKind.simulator.displayName,
                    summary: "Simulator \(device.name) is unavailable and is a stronger cleanup candidate than usable devices.",
                    evidence: classification.evidence + ["simctl reports unavailable.", "udid \(device.udid)."],
                    recommendedAction: "Remove this unavailable device from Xcode or simctl after review. Do not delete Booted or available devices.",
                    kind: .simulator
                )
            }
        }

        guard let reason = inUseReason(for: node, pathUse: pathUse) else {
            return classification
        }
        return SafetyClassification(
            level: .activeOrInUse,
            confidence: max(classification.confidence, 0.9),
            category: classification.category,
            summary: "A running tool may have this path open.",
            evidence: classification.evidence + [reason],
            recommendedAction: "Do not delete while that tool is running. Close it, then rescan.",
            kind: classification.kind
        )
    }

    private func inUseReason(for node: FileNode, pathUse: PathUseSnapshot) -> String? {
        let path = node.path.lowercased()
        if pathUse.isPathOpen(node.path) {
            return "lsof snapshot has this path open."
        }
        if let device = pathUse.simulatorInventory.device(matching: node.path), device.isBooted {
            return "Simulator \(device.name) is Booted."
        }
        if pathUse.xcodeFamilyActive, isXcodeOwnedPath(path) {
            return "Xcode, Simulator, or xcodebuild is running."
        }
        if pathUse.cursorActive, isCursorApplicationCache(path: path) {
            return "Cursor is running."
        }
        if pathUse.nodePackageActive, node.rebuildEvidence.contains(.packageLockfile) || path.contains("/node_modules") || path.contains("/.npm") || path.contains("/pnpm/store") || path.contains("/.yarn/") || path.contains("/.bun/install/cache") {
            return "A Node or package-manager process is running; closed file handles do not prove dependencies are idle."
        }
        if pathUse.xcodeFamilyActive, path.hasSuffix("/.build") || path.contains("/.build/") || node.rebuildEvidence.contains(.cargoManifest) {
            return "A developer tool is running; close build tools and rescan."
        }
        if pathUse.cargoActive, isCargoOwnedPath(path) {
            return "Cargo or rustc is running."
        }
        if pathUse.dockerActive, isDockerStorage(path: path, name: node.name.lowercased()) {
            return "Docker is running."
        }
        return nil
    }

    private func isXcodeOwnedPath(_ path: String) -> Bool {
        isTemporaryRoot(path: path)
            || path.contains("/library/developer/xcode/deriveddata")
            || path.contains("/library/developer/coresimulator")
            || path.contains("/library/developer/xctestdevices")
            || path.contains("/library/developer/xcode/ios devicesupport")
            || path.contains("/library/developer/xcode/watchos devicesupport")
            || path.contains("/library/developer/xcode/tvos devicesupport")
    }

    private func isCargoOwnedPath(_ path: String) -> Bool {
        path.contains("/.cargo/")
            || path.hasSuffix("/.cargo")
            || path.contains("/.rustup/")
            || path.hasSuffix("/target")
            || path.contains("/target/")
    }

    private func isSystemCritical(path: String) -> Bool {
        (path == "/system" || (path.hasPrefix("/system/") && !path.hasPrefix("/system/volumes/vm")))
            || (path == "/bin" || path.hasPrefix("/bin/"))
            || (path == "/sbin" || path.hasPrefix("/sbin/"))
            || (path == "/usr/bin" || path.hasPrefix("/usr/bin/"))
            || (path == "/usr/sbin" || path.hasPrefix("/usr/sbin/"))
            || (path == "/private/var/db" || path.hasPrefix("/private/var/db/"))
            || (path == "/library/apple" || path.hasPrefix("/library/apple/"))
    }

    private func isSystemVirtualMemory(path: String) -> Bool {
        path.hasPrefix("/system/volumes/vm")
    }

    private func isDockerStorage(path: String, name: String) -> Bool {
        name == "docker.raw"
            || name == "docker.qcow2"
            || path.hasSuffix("/docker.raw")
            || path.hasSuffix("/docker.qcow2")
            || path.contains("/library/containers/com.docker.docker/data/vms/")
            || path.hasSuffix("/library/containers/com.docker.docker/data/vms")
            || path.contains("/docker/volumes/")
    }

    private func isAppleWallpaperAerials(path: String) -> Bool {
        path.contains("/library/application support/com.apple.wallpaper/aerials/videos")
    }

    private func isCoreSimulatorCache(path: String) -> Bool {
        path == "/library/developer/coresimulator/caches"
            || path.hasSuffix("/library/developer/coresimulator/caches")
            || path.contains("/library/developer/coresimulator/caches/")
    }

    private func isSimulatorRuntime(path: String) -> Bool {
        path.contains("/library/developer/coresimulator/devices")
            || path.contains("/library/developer/xctestdevices")
    }

    private func isXcodeArchives(path: String) -> Bool {
        path.contains("/library/developer/xcode/archives")
    }

    private func isAndroidEmulatorDevice(path: String) -> Bool {
        path.contains("/.android/avd/")
            || path.hasSuffix("/.android/avd")
    }

    private func isRustToolchainStore(path: String) -> Bool {
        path.contains("/.rustup/toolchains/")
            || path.hasSuffix("/.rustup/toolchains")
    }

    private func isPythonVirtualenv(name: String, components: [String]) -> Bool {
        name == ".venv" || name == "venv" || components.contains(".venv") || components.contains("venv")
    }

    private func isCondaPackageCache(path: String) -> Bool {
        path.contains("/anaconda3/pkgs/")
            || path.hasSuffix("/anaconda3/pkgs")
            || path.contains("/miniconda3/pkgs/")
            || path.hasSuffix("/miniconda3/pkgs")
    }

    private func isCodexUserData(path: String) -> Bool {
        path.contains("/.codex/sessions")
            || path.contains("/.codex/worktrees")
    }

    private func isNotionLocalState(path: String) -> Bool {
        path.contains("/library/application support/notion/partitions")
    }

    private func isCursorUserData(path: String) -> Bool {
        path.contains("/library/application support/cursor/user")
    }

    private func isCursorApplicationCache(path: String) -> Bool {
        guard path.contains("/library/application support/cursor/") else {
            return false
        }
        if isCursorUserData(path: path) {
            return false
        }
        return path.contains("/cache")
            || path.contains("/cacheddata")
            || path.contains("/cachedextensionvsixs")
            || path.contains("/code cache")
            || path.contains("/gpucache")
            || path.contains("/dawngraphitecache")
            || path.contains("/dawnwebgpucache")
            || path.contains("/shadercache")
            || path.hasSuffix("/logs")
            || path.contains("/logs/")
    }

    private func isResearchDataCache(path: String) -> Bool {
        if path.contains("/quants-lab/output") {
            return true
        }
        let isResearchPath = path.contains("/research-")
            || path.contains("/research/")
            || path.contains("/backtest")
            || path.contains("quants")
            || path.contains("hummingbot")
        let isGeneratedData = path.contains("/app/data/cache/")
            || path.contains("/output/backtests")
            || path.hasSuffix("/output")
            || path.contains("/output/")
        return isResearchPath && isGeneratedData
    }

    private func isDownloadedResearchLibrary(path: String) -> Bool {
        path.contains("/downloads/researchlibrary")
            || path.contains("/downloads/research-library")
            || (path.contains("/research/") && path.contains("/downloads/library"))
    }

    private func isAIModelStore(path: String) -> Bool {
        path.contains("/.lmstudio/models")
            || path.contains("/.ollama/models")
            || path.contains("/.cache/huggingface")
            || path.contains("/stable-diffusion")
            || path.contains("/comfyui/models")
    }

    private func isIOSBackup(path: String) -> Bool {
        path.contains("/library/application support/mobilesync/backup")
    }

    private func isMailDownloads(path: String) -> Bool {
        path.contains("/library/mail downloads")
    }

    private func isTrash(path: String, name: String) -> Bool {
        name == ".trash" || path.hasSuffix("/.trash") || path.contains("/.trash/")
    }

    private func isTemporaryRoot(path: String) -> Bool {
        path == "/tmp"
            || path == "/private/tmp"
            || path.hasSuffix("//tmp")
            || path.hasSuffix("/private/tmp")
            || path.hasPrefix("/tmp/")
            || path.hasPrefix("/private/tmp/")
    }

    private func isApplicationSupportDatabase(path: String, fileExtension: String) -> Bool {
        let databaseExtensions = ["db", "sqlite", "sqlite3", "vscdb"]
        return path.contains("/library/application support/")
            && databaseExtensions.contains(fileExtension)
    }

    private func isAndroidBuildIntermediates(path: String, name: String) -> Bool {
        name == "intermediates" && path.contains("/build/intermediates")
    }

    private func isPackageCache(path: String, name: String, components: [String]) -> Bool {
        let exactNames = [
            ".build",
            "deriveddata",
            ".dart_tool",
            ".pytest_cache",
            "__pycache__",
            ".mypy_cache",
            ".ruff_cache",
            "buck-out",
            "bazel-out",
            ".bazel-cache"
        ]
        return exactNames.contains(name)
            || name.hasPrefix("deriveddata-")
            || components.contains { exactNames.contains($0) || $0.hasPrefix("deriveddata-") }
            || name == "node_modules"
            || path.hasSuffix("/node_modules")
            || path.contains("/node_modules/")
            || path.contains("/node_modules/.cache")
            || path.contains("/library/developer/xcode/deriveddata")
            || path.contains("/library/developer/xcode/ios devicesupport")
            || path.contains("/library/developer/xcode/documentationcache")
            || path.contains("/.gradle/caches")
            || path.contains("/.npm/")
            || path.hasSuffix("/.npm")
            || path.contains("/pnpm/store")
            || path.contains("/library/pnpm/store/")
            || path.hasSuffix("/library/pnpm/store")
            || path.contains("/.local/share/pnpm/store")
            || path.contains("/.cargo/registry")
            || path.contains("/.cargo/git")
            || path.contains("/.m2/repository")
            || path.contains("/library/caches/homebrew")
            || path.contains("/library/caches/cocoapods")
            || path.contains("/library/caches/pip")
            || path.contains("/library/caches/yarn")
            || path.contains("/.yarn/berry/cache")
            || path.contains("/.cache/uv")
            || path.contains("/.cache/pip")
            || path.contains("/.cache/puppeteer")
            || path.contains("/.cache/ms-playwright")
            || path.contains("/.composer/cache")
            || path.contains("/.bun/install/cache")
            || path.contains("/go/pkg/mod")
            || path.contains("/library/caches/go-build")
            || path.contains("/.codex/tmp")
            || path.contains("/library/application support/code/cache")
            || path.contains("/library/application support/code/cacheddata")
            || path == userLibraryCachesPath
            || path.hasPrefix(userLibraryCachesPath + "/")
            || (name == ".cache" && components.contains("node_modules"))
    }

    private func packageCacheKind(path: String, name: String) -> ScanKind {
        if name == ".build" || name == "deriveddata" || name == "__pycache__"
            || name == "buck-out" || name == "bazel-out" || name == ".bazel-cache"
            || path.contains("/library/developer/xcode/deriveddata")
            || path.contains("/library/developer/xcode/ios devicesupport")
            || path.contains("/library/developer/xcode/documentationcache")
        {
            return .rebuildableCache
        }
        if name == ".pytest_cache" || name == ".mypy_cache" || name == ".ruff_cache" || name == ".dart_tool" {
            return .rebuildableCache
        }
        if name == "node_modules" || path.hasSuffix("/node_modules") || path.contains("/node_modules/") {
            return .packageCache
        }
        return .packageCache
    }

    private func isCrashDump(path: String, fileExtension: String) -> Bool {
        fileExtension == "dmp"
            || fileExtension == "crash"
            || fileExtension == "ips"
            || path.contains("/crashpad/")
    }

    private func isLogFile(path: String, name: String, fileExtension: String) -> Bool {
        fileExtension == "log"
            || name.contains(".log.")
            || path.contains("/logs/")
            || path.hasSuffix("/library/logs")
            || path.contains("/library/logs/")
    }

    private func isTemporaryLocation(path: String) -> Bool {
        isTemporaryRoot(path: path)
            || path.contains("/private/var/folders/")
            || path.contains("/library/caches/")
            || path.contains("/crashpad/")
            || path.contains("/library/logs/")
    }

    private func isProjectOrUserData(path: String) -> Bool {
        path.contains("/users/")
            && (
                path.contains("/dev/")
                    || path.contains("/documents/")
                    || path.contains("/desktop/")
                    || path.contains("/downloads/")
                    || path.contains("/workspace/")
            )
    }

    private func isOlderThan(days: Int, date: Date?) -> Bool {
        guard let date else {
            return false
        }

        let threshold = Date().addingTimeInterval(TimeInterval(-days * 24 * 60 * 60))
        return date < threshold
    }
}
