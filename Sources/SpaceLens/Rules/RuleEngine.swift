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

        if isGeneratedBuildOutput(name: name, components: pathComponents) {
            return SafetyClassification(
                level: .generatedOutput,
                confidence: 0.88,
                category: "Generated output",
                summary: "This looks like generated build output.",
                evidence: ["Matched a build output directory name.", "Generated outputs are usually reproducible from source."],
                recommendedAction: "Queue for review if the project is not currently building."
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
        path.hasPrefix("/system/")
            || path.hasPrefix("/bin/")
            || path.hasPrefix("/sbin/")
            || path.hasPrefix("/usr/bin/")
            || path.hasPrefix("/usr/sbin/")
            || path.hasPrefix("/private/var/db/")
            || path.hasPrefix("/library/apple/")
    }

    private func isDockerStorage(path: String, name: String) -> Bool {
        name == "docker.raw"
            || path.contains("/library/containers/com.docker.docker/data/vms/")
            || path.contains("/docker/volumes/")
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
            || path.contains("/node_modules/.cache")
            || path.contains("/library/developer/xcode/deriveddata")
            || path.contains("/.gradle/caches")
            || path.contains("/library/caches/")
            || (name == ".cache" && components.contains("node_modules"))
    }

    private func isGeneratedBuildOutput(name: String, components: [String]) -> Bool {
        if name != "build" && name != "dist" && name != "target" {
            return false
        }

        return components.contains("dev")
            || components.contains("workspace")
            || components.contains("sources")
            || components.contains("users")
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
