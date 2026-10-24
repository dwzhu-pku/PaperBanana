---
title: PaperBanana
emoji: 🍌
colorFrom: yellow
colorTo: gray
sdk: docker
app_port: 7860
pinned: false
---

# PaperBanana hosted space

Starter README for a **new** Docker Space. Do not replace the Streamlit demo in `dwzhu/PaperBanana`.

Copy `hosted/Dockerfile` to this Space's root `Dockerfile`. Set the secrets and the private bucket described in `docs/hosted-deploy.md` in the PaperBanana source repository. Run the local compose stack in that repository before pointing this Space at real OAuth or a real sponsor key.

The site listens on port 7860. Keep a single replica.
