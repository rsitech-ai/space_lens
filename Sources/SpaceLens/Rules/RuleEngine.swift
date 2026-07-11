import Foundation

public struct RuleEngine: Sendable {
    public init() {}

    public func classify(_ node: FileNode) -> SafetyClassification {
        let path = node.path.lowercased()
        let name = node.name.lowercased()
        let pathComponents = node.url.pathComponents.map { $0.lowercased() }
        let fileExtension = node.url.pathExtension.lowercased()

        if isSystemCritical(path: path) {
            return SafetyClassification(
                level: .systemCritical,
                confidence: 0.98,
                category: "System/private data",
                summary: "This is inside a protected macOS location.",
                evidence: ["Path is under a protected system/private directory.", "SpaceLens never recommends raw cleanup here."],
                recommendedAction: "Do not delete from SpaceLens."
            )
        }

        if isSystemVirtualMemory(path: path) {
            return SafetyClassification(
                level: .systemCritical,
                confidence: 0.99,
                category: "macOS virtual memory",
                summary: "This is macOS swap or virtual memory state.",
                evidence: ["Matched /System/Volumes/VM.", "Manual deletion can destabilize macOS."],
                recommendedAction: "Do not delete manually. Close heavy apps or reboot if swap is high."
            )
        }

        if isDockerStorage(path: path, name: name) {
            return SafetyClassification(
                level: .activeOrInUse,
                confidence: 0.96,
                category: "Docker storage",
                summary: "This appears to be Docker-owned VM or container storage.",
                evidence: ["Matched Docker Desktop storage path or Docker.raw.", "Manual deletion can break containers and volumes."],
                recommendedAction: "Use Docker cleanup or compaction tools, then rescan."
            )
        }

        if isAppleWallpaperAerials(path: path) {
            return SafetyClassification(
                level: .safeTemp,
                confidence: 0.92,
                category: "Apple wallpaper downloads",
                summary: "These are downloaded Apple aerial wallpaper videos.",
                evidence: ["Matched the Apple wallpaper aerial video cache.", "macOS can redownload wallpapers later."],
                recommendedAction: "Queue for review, then move to the Bin if you do not use these wallpapers."
            )
        }

        if isCoreSimulatorCache(path: path) {
            return SafetyClassification(
                level: .rebuildableCache,
                confidence: 0.94,
                category: "Simulator cache",
                summary: "This is Xcode Simulator cache data.",
                evidence: ["Matched CoreSimulator cache storage.", "Xcode and Simulator can rebuild cache files."],
                recommendedAction: "Queue for review; close Simulator and Xcode before cleanup."
            )
        }

        if isAndroidEmulatorDevice(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.82,
                category: "Android emulator device",
                summary: "This looks like an Android virtual device image.",
                evidence: ["Matched an .android/avd device path.", "Deleting it removes that emulator device state."],
                recommendedAction: "Reveal and delete only if you do not need this emulator."
            )
        }

        if isRustToolchainStore(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.82,
                category: "Rust toolchains",
                summary: "This stores installed Rust toolchains.",
                evidence: ["Matched rustup toolchain storage.", "Unused old toolchains are removable, but active stable/nightly toolchains may be needed."],
                recommendedAction: "Use rustup to remove specific unused toolchains."
            )
        }

        if isCondaPackageCache(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.86,
                category: "Conda package cache",
                summary: "This is Conda package cache data.",
                evidence: ["Matched anaconda3/pkgs.", "Conda has its own cleanup tooling."],
                recommendedAction: "Prefer conda clean before raw deletion."
            )
        }

        if isCodexSessions(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.8,
                category: "Codex sessions",
                summary: "These are local Codex session transcripts and continuity data.",
                evidence: ["Matched .codex/sessions.", "Old sessions may be disposable, but they can contain useful history."],
                recommendedAction: "Review retention needs before deleting old sessions."
            )
        }

        if isNotionLocalState(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.78,
                category: "Notion local state",
                summary: "This appears to be Notion local cache or synced state.",
                evidence: ["Matched Notion Partitions storage.", "Notion may need to re-sync after cleanup."],
                recommendedAction: "Close Notion and review before cleanup."
            )
        }

        if isCursorHistory(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.8,
                category: "Cursor history",
                summary: "This is Cursor local history or global extension state.",
                evidence: ["Matched Cursor User storage.", "Some content may be useful project or agent history."],
                recommendedAction: "Review inside Cursor before deleting local history or global storage."
            )
        }

        if isTradingResearchCache(path: path) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.84,
                category: "Trading research cache",
                summary: "This looks generated, but it belongs to trading research.",
                evidence: ["Matched quants-lab cache/backtest paths.", "Large generated data may still be needed for reproducibility."],
                recommendedAction: "Archive or delete only after confirming the run/data is reproducible or obsolete."
            )
        }

        if isDownloadedResearchLibrary(path: path) {
            return SafetyClassification(
                level: .largeButValuable,
                confidence: 0.9,
                category: "Research corpus",
                summary: "This looks like a downloaded research/library corpus.",
                evidence: ["Matched the risercz downloaded library path.", "The content is user/project data, not a disposable cache."],
                recommendedAction: "Do not delete unless you explicitly decide this corpus is disposable."
            )
        }

        if isAIModelStore(path: path) {
            return SafetyClassification(
                level: .largeButValuable,
                confidence: 0.92,
                category: "AI models",
                summary: "This looks like a locally installed model store.",
                evidence: ["Matched known local model cache path.", "Models are large but user-managed assets."],
                recommendedAction: "Review manually before removing any model."
            )
        }

        if isApplicationSupportDatabase(path: path, fileExtension: fileExtension) {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.9,
                category: "App state database",
                summary: "This appears to be application state, not a disposable cache.",
                evidence: ["Located under Library/Application Support.", "Database-like extension: .\(fileExtension)."],
                recommendedAction: "Review in the owning app before deleting."
            )
        }

        if isPackageCache(path: path, name: name, components: pathComponents) {
            return SafetyClassification(
                level: .rebuildableCache,
                confidence: 0.9,
                category: "Package/build cache",
                summary: "This is a cache that tools can usually rebuild.",
                evidence: ["Matched known cache/build directory.", "Deleting may slow the next build or package install."],
                recommendedAction: "Queue for review; use Trash only after checking the project is inactive."
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
                recommendedAction: isTemp ? "Queue for review before Trash." : "Inspect before deletion."
            )
        }

        if isLogFile(path: path, name: name, fileExtension: fileExtension) {
            let old = isOlderThan(days: 14, date: node.modifiedAt)
            return SafetyClassification(
                level: old ? .safeTemp : .unknownReview,
                confidence: old ? 0.78 : 0.58,
                category: "Logs",
                summary: old ? "This appears to be an old log file." : "This appears to be a recent or active log file.",
                evidence: ["Matched log naming pattern.", old ? "Last modified more than 14 days ago." : "Recent logs may still be useful or active."],
                recommendedAction: old ? "Queue for review before Trash." : "Reveal and check whether the owning process still needs it."
            )
        }

        if isProjectOrUserData(path: path) {
            return SafetyClassification(
                level: .largeButValuable,
                confidence: 0.74,
                category: "Project/user data",
                summary: "This is in a user project or document area.",
                evidence: ["Matched user workspace or document path.", "SpaceLens treats source, datasets, and documents as valuable by default."],
                recommendedAction: "Review manually; do not treat as disposable."
            )
        }

        if node.effectiveSize >= 1_000_000_000 {
            return SafetyClassification(
                level: .unknownReview,
                confidence: 0.65,
                category: "Unknown large item",
                summary: "This is large, but SpaceLens does not have a safe cleanup rule for it.",
                evidence: ["Size is at least 1 GB.", "No deterministic safe rule matched."],
                recommendedAction: "Inspect ownership and purpose before taking action."
            )
        }

        return SafetyClassification(
            level: .unknownReview,
            confidence: 0.5,
            category: "Unknown",
            summary: "No safe cleanup rule matched this item.",
            evidence: ["No known cache, temp, build, or tool-owned pattern matched."],
            recommendedAction: "Review only."
        )
    }

    private func isSystemCritical(path: String) -> Bool {
        (path.hasPrefix("/system/") && !path.hasPrefix("/system/volumes/vm"))
            || path.hasPrefix("/bin/")
            || path.hasPrefix("/sbin/")
            || path.hasPrefix("/usr/bin/")
            || path.hasPrefix("/usr/sbin/")
            || path.hasPrefix("/private/var/db/")
            || path.hasPrefix("/library/apple/")
    }

    private func isSystemVirtualMemory(path: String) -> Bool {
        path.hasPrefix("/system/volumes/vm")
    }

    private func isDockerStorage(path: String, name: String) -> Bool {
        name == "docker.raw"
            || path.contains("/library/containers/com.docker.docker/data/vms/")
            || path.contains("/docker/volumes/")
    }

    private func isAppleWallpaperAerials(path: String) -> Bool {
        path.contains("/library/application support/com.apple.wallpaper/aerials/videos")
    }

    private func isCoreSimulatorCache(path: String) -> Bool {
        path == "/library/developer/coresimulator/caches"
            || path.hasSuffix("/library/developer/coresimulator/caches")
    }

    private func isAndroidEmulatorDevice(path: String) -> Bool {
        path.contains("/.android/avd/")
            || path.hasSuffix("/.android/avd")
    }

    private func isRustToolchainStore(path: String) -> Bool {
        path.contains("/.rustup/toolchains/")
            || path.hasSuffix("/.rustup/toolchains")
    }

    private func isCondaPackageCache(path: String) -> Bool {
        path.contains("/anaconda3/pkgs/")
            || path.hasSuffix("/anaconda3/pkgs")
            || path.contains("/miniconda3/pkgs/")
            || path.hasSuffix("/miniconda3/pkgs")
    }

    private func isCodexSessions(path: String) -> Bool {
        path.contains("/.codex/sessions/")
            || path.hasSuffix("/.codex/sessions")
    }

    private func isNotionLocalState(path: String) -> Bool {
        path.contains("/library/application support/notion/partitions")
    }

    private func isCursorHistory(path: String) -> Bool {
        path.contains("/library/application support/cursor/user/history")
            || path.contains("/library/application support/cursor/user/globalstorage")
    }

    private func isTradingResearchCache(path: String) -> Bool {
        path.contains("/dev/trading/rsibot/quants-lab/app/data/cache/lob")
            || path.contains("/dev/trading/rsibot/quants-lab/output/backtests")
    }

    private func isDownloadedResearchLibrary(path: String) -> Bool {
        path.contains("/dev/new/alpha-vistula/risercz/python/universal/downloads/library")
    }

    private func isAIModelStore(path: String) -> Bool {
        path.contains("/.lmstudio/models")
            || path.contains("/.ollama/models")
            || path.contains("/.cache/huggingface")
            || path.contains("/stable-diffusion")
            || path.contains("/comfyui/models")
    }

    private func isApplicationSupportDatabase(path: String, fileExtension: String) -> Bool {
        let databaseExtensions = ["db", "sqlite", "sqlite3", "vscdb"]
        return path.contains("/library/application support/")
            && databaseExtensions.contains(fileExtension)
    }

    private func isPackageCache(path: String, name: String, components: [String]) -> Bool {
        let exactNames = [".build", "deriveddata", ".dart_tool", ".pytest_cache", "__pycache__", ".mypy_cache", ".ruff_cache"]
        return exactNames.contains(name)
            || components.contains { exactNames.contains($0) }
            || path.contains("/node_modules/.cache")
            || path.contains("/library/developer/xcode/deriveddata")
            || path.contains("/.gradle/caches")
            || path.contains("/library/caches/")
            || (name == ".cache" && components.contains("node_modules"))
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
    }

    private func isTemporaryLocation(path: String) -> Bool {
        path.contains("/tmp/")
            || path.contains("/private/var/folders/")
            || path.contains("/library/caches/")
            || path.contains("/crashpad/")
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
