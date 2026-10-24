# Releasing ShatterBar

1. Update Core.lua, every manifest, tools/package.py, and RELEASE_NOTES.md together.
2. Run `python tests/run.py` with `lupa==2.6`.
3. Run `python tools/release.py --tag v0.1.14` and `python tools/curseforge.py --tag v0.1.14 --dry-run`.
4. Commit and push, then create and push the matching annotated version tag.
5. The tagged workflow tests and validates all five archives, then publishes GitHub assets.
   Tags containing a hyphen are prereleases; plain version tags are regular releases.
6. CurseForge upload runs if the repository variable CF_PROJECT_ID is configured.
   ShatterBar's project ID is 1762310; CF_PROJECT_ID is configured on GitHub.
   The CF_API_KEY repository secret is configured for authenticated uploads.
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

## Initial CurseForge submission

The ShatterBar project was created on 2026-10-23:
https://authors.curseforge.com/#/projects/1762310/files

All five v0.1.14 archives were submitted manually with automatic publication after
moderator approval. Do not rerun the existing-tag upload workflow for v0.1.14;
that would duplicate these files.

| Client | CurseForge file ID | Game version |
| --- | --- | --- |
| Retail | 9303720 | 12.1.5 |
| Forever | 9303729 | 1.60.1 |
| Classic Era | 9303733 | 1.15.9 |
| Mists Classic | 9303738 | 5.5.4 |
| Burning Crusade | 9303747 | 2.5.6 |

The listing includes the approved icon and banner, description, GitHub source link,
and seven gameplay/options screenshots. Project visibility depends on moderation.
