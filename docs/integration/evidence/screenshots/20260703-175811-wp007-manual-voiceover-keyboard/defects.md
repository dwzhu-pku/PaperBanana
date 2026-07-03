# WP-007 Manual VoiceOver Defects

Status: blocked partial packet. No route is release-accepted in this packet.

## Route Disposition

| Route ID | Status | Defect or limitation ID | Release-owner acceptance required? |
|---|---|---|---|
| VO-01 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-02 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-03 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-04 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-05 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-06 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-07 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-08 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-09 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-10 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-11 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-12 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-13 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-14 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-15 | not_run | WP007-MANUAL-VOICEOVER-001 | no |
| VO-16 | not_run | WP007-MANUAL-VOICEOVER-001 | no |

## Defect Log

| Defect ID | Route ID | Severity | Observed behavior | Expected behavior | Screenshot or artifact | Disposition |
|---|---|---|---|---|---|---|
| WP007-MANUAL-VOICEOVER-001 | VO-01..VO-16 | major | The app was installed, opened, moved to the same display, and captured with screenshots plus AX/System Events sidecars, but route-by-route audible VoiceOver speech output and keyboard traversal were not completed. Starting VoiceOver produced Apple's VoiceOver Quickstart helper, which is environment preflight evidence but not a reliable completed speech transcript for the routes. | A release-ready WP-007 packet must contain real observed speech and keyboard traversal results for every VO-01 through VO-16 route, or explicit pass_with_limitation entries with named release-owner acceptance. | `screenshots/main-window-initial.png`, `screenshots/prompt-studio.png`, `screenshots/settings-workspace.png`, `screenshots/main-window-inactive-behind-settings.png`, `sidecars/ax-main-window.txt`, `sidecars/environment-process-host-snapshot.txt`, `sidecars/process-cleanup-after.txt` | open |

## Release Owner Acceptance

No accepted limitations are recorded in this packet. The route dispositions are `not_run`, so WP-007 remains open and requires a manual release-owner-reviewed VoiceOver and keyboard traversal packet before closure.
