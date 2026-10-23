# Releasing ShatterBar

1. Update Core.lua, every manifest, tools/package.py, and RELEASE_NOTES.md together.
2. Run `python tests/run.py` with `lupa==2.6`.
3. Run `python tools/release.py --tag v0.1.14` and `python tools/curseforge.py --tag v0.1.14 --dry-run`.
4. Commit and push, then create and push the matching annotated version tag.
5. The tagged workflow tests and validates all five archives, then publishes GitHub assets.
   Tags containing a hyphen are prereleases; plain version tags are regular releases.
6. CurseForge upload runs if the repository variable CF_PROJECT_ID is configured.
   Set it to ShatterBar's numeric project ID and add the repository secret CF_API_KEY.
   Never use Mailwright's project ID. Do not put API keys into source or chat.
7. If the GitHub release was published before CurseForge was configured, use the
   **Publish existing tag to CurseForge** manual workflow with the existing tag.
   Inspect CurseForge before retrying any interrupted or partially completed upload.

## Distribution

GitHub releases include retail, forever, classic, mists, and bcc ZIPs, checksums.json,
and release.json for addon-manager flavor metadata. Each ZIP has a top-level
ShatterBar folder with client-specific manifests and required data files.

CurseForge, Wago, WoWInterface, and WowUp listings each need their own project setup.
WowUp can install a tagged GitHub release by URL; Hub discovery requires separate setup.

Platform description: LISTING_DESCRIPTION.md.
Approved artwork: artwork/ShatterBar-icon-v2.png and artwork/ShatterBar-banner-v2.png.
Screenshots: artwork/screenshots/README.md.

Private reports, backups, SavedVariables, and working files stay excluded from Git.
