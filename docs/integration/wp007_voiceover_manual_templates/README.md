# WP-007 VoiceOver Manual Templates

These templates support the WP-007 manual keyboard and VoiceOver traversal
defined by `docs/integration/WP007_MANUAL_VOICEOVER_ARTIFACT_CONTRACT.md` and
`docs/integration/evidence/20260623-145051_b81a399_WP-007-manual-voiceover-traversal-packet.md`.

They are preparation artifacts only. They do not contain completed observations
and do not close WP-007.

Copy the templates into a new SHA-linked evidence directory before the manual
pass, then replace every placeholder with observed data from the candidate app.
Do not paste provider secrets, auth headers, private manuscript text, or raw
provider payloads into the completed files.

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

The completed run must be reviewed by a human. Automated validators may reject
missing or malformed artifacts; they must not mark WP-007 complete.

After completing the manual pass, run the structural validator:

```bash
python docs/integration/wp007_voiceover_manual_templates/validate_completed_packet.py \
  <completed-artifact-directory>
```

The validator checks packet structure, placeholders, required routes, and
obvious secret patterns. It cannot verify the spoken output and does not close
WP-007.
