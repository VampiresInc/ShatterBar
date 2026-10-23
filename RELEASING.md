# Releasing ShatterBar

The initial release is a public preview. Keep the client testing status accurate.

1. Update Core.lua, every manifest, tools/package.py, README.md, and RELEASE_NOTES.md together.
2. Run `python tests/run.py` with `lupa==2.6`, then `python tools/release.py --tag v0.1.14`.
3. Add reviewed screenshots to artwork/screenshots and embed them in README.md.
4. Push the source to the intended GitHub repository, then push the matching version tag.
5. The tagged workflow reruns tests, validates all client archives, and publishes a GitHub prerelease.
6. For CurseForge, create the ShatterBar project first. Its project ID and publishing configuration
   must belong to ShatterBar; never reuse Mailwright's project ID. Configure its API key as a
   repository secret when enabling CurseForge uploads. The current workflow publishes to GitHub only.

First launch also needs a project icon and description for the CurseForge listing.
Do not claim the four non-Retail clients are tested until their acceptance checks pass.

Work files, installed-addon backups, SavedVariables diagnostics, and distribution
archives are excluded from Git. GitHub release assets contain only the packaged addon.

## Distribution targets

GitHub, CurseForge, Wago Addons, WoWInterface, and WowUp are planned for launch.
Each hosting project needs its own project identity; no ShatterBar project IDs have
been supplied yet. Current automation publishes only GitHub. Add other upload jobs
only after the correct project IDs and repository secrets are available.

WowUp can install a tagged GitHub release by URL. WowUp Hub listing/discovery is a
separate setup step; do not claim automatic search availability until verified.
Official guide: https://wowup.io/guide/get-addons/overview
Hub guide: https://dev.wowup.io/guide/wowup/hub
Wago API: https://docs.wago.io/

Original listing artwork is in artwork/ShatterBar-icon-v2.png and
artwork/ShatterBar-banner-v2.png. Platform-specific exports/crops may be needed
by each listing form. Gameplay screenshots are still needed; use the screenshot guide.
