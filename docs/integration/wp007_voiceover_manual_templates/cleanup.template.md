# WP-007 Manual VoiceOver Cleanup

Status: template; replace placeholders during the manual run

## Process Cleanup

- PaperBanana app process running after cleanup: `<no or defect id>`
- Legacy backend process from this worktree running after cleanup: `<no or defect id>`
- VoiceOver helper process unexpectedly left by the test: `<no or defect id>`
- Temporary local HTTP server running after cleanup: `<no or defect id>`

## Preference And Data Cleanup

- Temporary app-scoped appearance override restored: `<yes/no/not used>`
- Temporary app-scoped text-size override restored: `<yes/no/not used>`
- Temporary repository path override restored: `<yes/no/not used>`
- Temporary Application Support root removed or archived: `<record action>`
- Synthetic checkout removed or archived: `<record action>`

## Safety Confirmation

- No live provider generation was started: `<confirm>`
- No `codex exec` run was started: `<confirm>`
- No provider secret, auth header, or private path was copied into evidence: `<confirm>`
- No destructive cleanup/reset was performed on user data: `<confirm>`

## Remaining Cleanup Exceptions

Record any intentional leftover artifact paths and owner-approved reason.
