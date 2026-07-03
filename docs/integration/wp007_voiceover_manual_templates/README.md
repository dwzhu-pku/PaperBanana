# WP-007 VoiceOver Manual Templates

These templates support an optional future WP-007 manual keyboard and VoiceOver
traversal defined by
`docs/integration/WP007_MANUAL_VOICEOVER_ARTIFACT_CONTRACT.md` and
`docs/integration/evidence/20260623-145051_b81a399_WP-007-manual-voiceover-traversal-packet.md`.
Per `EV-20260703-104`, completed VoiceOver speech-output traversal is no longer
required as a native-first release gate.

They are preparation artifacts only. They do not contain completed observations,
do not close or block WP-007, and must not be used to claim VoiceOver validation
or screen-reader-complete support.

If a future reviewer explicitly chooses to run the optional manual pass, copy
the templates into a new SHA-linked evidence directory, then replace every
placeholder with observed data from the candidate app. Do not paste provider
secrets, auth headers, private manuscript text, or raw provider payloads into
the completed files.

Required files:

- `voiceover-speech-output.template.tsv`
- `keyboard-traversal.template.tsv`
- `environment.template.md`
- `defects.template.md`
- `cleanup.template.md`

Completed packet file names should remove `.template`:

- `voiceover-speech-output.tsv`
- `keyboard-traversal.tsv`
- `environment.md`
- `defects.md`
- `cleanup.md`

Any completed run must be reviewed by a human. Automated validators may reject
missing or malformed artifacts; they must not mark WP-007 complete or assert
release-level VoiceOver support.

After completing the manual pass, run the structural validator:

```bash
python docs/integration/wp007_voiceover_manual_templates/validate_completed_packet.py \
  <completed-artifact-directory>
```

The validator checks packet structure, placeholders, required routes,
same-display/no-live safety fields, route-disposition consistency,
Reference Examples coverage in `VO-04`/`VO-05`, explicit accepted-limitation
records, and obvious secret patterns in text sidecars. It cannot verify the
spoken output and does not close WP-007.
