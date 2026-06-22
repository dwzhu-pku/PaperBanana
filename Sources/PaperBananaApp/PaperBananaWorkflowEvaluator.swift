import Foundation

enum PaperBananaEvaluationSeverity: String, Equatable {
    case pass
    case warning
    case failure
}

enum PaperBananaEvaluationCheck: String, Equatable {
    case durableSpendTrace
    case invisibleSpend
    case metadataValidation
    case artifactPersistence
    case rawResponseRecovery
    case providerFailure
    case imageQuality
    case staleRunningRun
}

struct PaperBananaEvaluationFinding: Identifiable, Equatable {
    let id: String
    let check: PaperBananaEvaluationCheck
    let severity: PaperBananaEvaluationSeverity
    let subject: String
    let message: String
}

enum PaperBananaWorkflowEvaluator {
    static func evaluate(repoRootPath: String, fileManager: FileManager = .default) -> [PaperBananaEvaluationFinding] {
        let runs = NativeRunCockpitScanner.scan(repoRootPath: repoRootPath, fileManager: fileManager)
        let calls = ProviderRunLedgerScanner.scan(repoRootPath: repoRootPath, fileManager: fileManager)
        return evaluate(runs: runs, providerCalls: calls)
    }

    static func evaluate(
        runs: [NativeRunCockpitItem],
        providerCalls: [ProviderRunLedgerCall]
    ) -> [PaperBananaEvaluationFinding] {
        var findings: [PaperBananaEvaluationFinding] = []
        let visibleProviderCallIDs = Set(runs.flatMap(\.providerCallIDs))

        for run in runs {
            if run.providerCalls.contains(where: { $0.status != .running }),
               run.hasDurableSpendTrace == false {
                findings.append(finding(
                    .durableSpendTrace,
                    .failure,
                    run.title,
                    "Provider work is linked to a run without prompt, request, and event log files."
                ))
            }

            if run.status == .completed, run.outputURLs.isEmpty {
                findings.append(finding(
                    .artifactPersistence,
                    .failure,
                    run.title,
                    "Run is completed but no output artifact is visible."
                ))
            }

            if run.status == .completed,
               run.outputURLs.isEmpty == false,
               run.metadataURL == nil {
                findings.append(finding(
                    .metadataValidation,
                    .failure,
                    run.title,
                    "Completed output is visible but no output metadata companion is linked."
                ))
            }

            if run.outputURLs.isEmpty == false {
                for outputURL in run.outputURLs {
                    guard let quality = PaperBananaImageQualityInspector.inspect(outputURL) else {
                        findings.append(finding(
                            .imageQuality,
                            .warning,
                            run.title,
                            "Output artifact could not be inspected as an image: \(outputURL.lastPathComponent)."
                        ))
                        continue
                    }

                    for warning in quality.targetWarnings(for: run.resolution) {
                        findings.append(finding(
                            .imageQuality,
                            .warning,
                            run.title,
                            "\(outputURL.lastPathComponent): \(warning)"
                        ))
                    }
                }
            }

            if run.outputURLs.isEmpty, run.recoverableURLs.isEmpty == false {
                findings.append(finding(
                    .rawResponseRecovery,
                    .warning,
                    run.title,
                    "Run has recoverable raw provider output but no completed native artifact."
                ))
            }

            if run.status == .stalled {
                findings.append(finding(
                    .staleRunningRun,
                    .failure,
                    run.title,
                    "Run was still marked running after the stale-progress timeout and needs recovery or explicit cancellation."
                ))
            }
        }

        for call in providerCalls {
            if call.status != .running,
               visibleProviderCallIDs.contains(call.callID) == false,
               call.runDirectoryURL == nil {
                findings.append(finding(
                    .invisibleSpend,
                    .failure,
                    call.callID,
                    "Completed provider call is not linked to a native run folder."
                ))
            }

            if call.status == .failed {
                findings.append(finding(
                    .providerFailure,
                    .warning,
                    call.callID,
                    call.error.nilIfBlank ?? call.message.nilIfBlank ?? "Provider call failed."
                ))
            }
        }

        if findings.isEmpty {
            findings.append(finding(
                .durableSpendTrace,
                .pass,
                "PaperBanana",
                "No invisible spend, missing outputs, or unrecoverable provider artifacts were detected."
            ))
        }

        return findings
    }

    private static func finding(
        _ check: PaperBananaEvaluationCheck,
        _ severity: PaperBananaEvaluationSeverity,
        _ subject: String,
        _ message: String
    ) -> PaperBananaEvaluationFinding {
        PaperBananaEvaluationFinding(
            id: "\(check.rawValue):\(severity.rawValue):\(subject):\(message)",
            check: check,
            severity: severity,
            subject: subject,
            message: message
        )
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
