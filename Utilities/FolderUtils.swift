import Foundation

enum FolderUtils {
    /// Computes a hash for audio files in a folder using `shasum -a 256`, with a timeout failsafe.
    /// - Parameters:
    ///   - folderURL: Folder to scan
    ///   - timeout: Max duration (seconds) to allow the process to run
    ///   - completion: Hash string or nil on failure/timeout
    static func getHash(for folderURL: URL, timeout: TimeInterval = 10, completion: @escaping (String?) -> Void) {
        guard folderURL.isFileURL else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let path = folderURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let extensions = AudioFormat.supportedExtensions.map { $0.lowercased() }
            let extFilter = extensions.map { "-iname '*.\($0)'" }.joined(separator: " -o ")
            let findExpression = "\\( \(extFilter) \\)"

            let command = """
            find "$1" -type f \(findExpression) -exec ls -lT {} + | sort | shasum -a 256
            """

            let process = Process()
            process.launchPath = "/bin/sh"
            process.arguments = ["-c", command, "--", path]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            let timeoutTask = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                    Logger.info("Hash process timed out after \(timeout) seconds and was terminated.")
                }
            }

            do {
                try process.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutTask)
            } catch {
                Logger.error("Failed to run hash command: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            process.waitUntilExit()
            timeoutTask.cancel()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()

            guard process.terminationStatus == 0,
                  let rawOutput = String(data: data, encoding: .utf8),
                  let hash = rawOutput.components(separatedBy: .whitespaces).first,
                  hash.count >= 16 else {
                Logger.warning("Hash command failed or returned malformed output.")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            DispatchQueue.main.async {
                completion(hash)
            }
        }
    }
    
    /// Async version of getHash for use with async/await
    static func getHashAsync(for folderURL: URL, timeout: TimeInterval = 10) async -> String? {
        await withCheckedContinuation { continuation in
            getHash(for: folderURL, timeout: timeout) { hash in
                continuation.resume(returning: hash)
            }
        }
    }
    
    /// Checks if folder's filesystem modification date has changed compared to stored date
    /// - Parameters:
    ///   - folderURL: The folder to check
    ///   - storedDate: The previously stored modification date
    ///   - tolerance: Time difference tolerance in seconds (default 1.0)
    /// - Returns: true if modification date has changed beyond tolerance
    static func modificationTimestampChanged(
        for folderURL: URL,
        comparedTo storedDate: Date,
        tolerance: TimeInterval = 1.0
    ) -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: folderURL.path)
            let currentModDate = attributes[.modificationDate] as? Date ?? Date.distantPast
            
            // Check if the difference exceeds tolerance
            let timeDifference = currentModDate.timeIntervalSince(storedDate)
            let hasChanged = abs(timeDifference) > tolerance
            
            if hasChanged {
                Logger.info("Folder timestamp changed: \(folderURL.lastPathComponent) (diff: \(timeDifference)s)")
            }
            
            return hasChanged
        } catch {
            Logger.warning("Failed to get modification date for \(folderURL.lastPathComponent): \(error)")
            // If we can't check, assume it changed to be safe
            return true
        }
    }
}
