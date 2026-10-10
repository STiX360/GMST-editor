# Publishing GMST Editor for OpenMW

## Release Configuration

VERSION is the version source; CHANGELOG.md must contain exactly one matching
section. Configuration retains the GMSTProfiles runtime identity, root-level
install paths, and the GMST-Editor-OpenMW ZIP naming convention. Version 0.4.0 is
configured as a stable release (`prerelease: false`). This status does not imply
that every GMST or modlist has been gameplay-tested.

## Local Checks

```sh
python -m pip install -r requirements-dev.txt
python -m pytest tests -q -p no:cacheprovider
python tools/release.py package
python tools/release.py verify
```

The explicit allowlist includes only eight production files. The ZIP, per-file
manifest, and SHA-256 checksums are written to dist/. Test-kit archives are written
separately to test-dist/ and are never uploaded by the release workflows.

## GitHub Releases

Configure this repository's GitHub remote and push reviewed source to main.
When ready to publish, create and push the matching tag (for this version,
`v0.4.0`). Tagging triggers tests and a deterministic package build, requires the
tagged commit to belong to main, and publishes the same verified artifacts to
GitHub Releases. Manual workflow dispatch builds only; it does not publish.
Do not move a published tag. Matching existing release assets are accepted on
retry; differing bytes or release status stop publication rather than overwriting.

## Nexus

Automatic Nexus uploads remain disabled unless repository variable
`NEXUSMODS_ENABLED` is explicitly set to `true`. Initially, create the mod page and
upload the verified GitHub production ZIP manually. Do not upload the test kit.

For later automatic updates, create GitHub environment `nexus` with secret
`NEXUSMODS_API_KEY` and variables `NEXUSMODS_FILE_ID` and `NEXUSMODS_MOD_ID`.
The latter is the API Unique Mod ID from Advanced, not the page URL number.
Use this project's IDs only. Enable `NEXUSMODS_ENABLED` after this setup.
The tag-triggered Nexus job runs after GitHub succeeds and verifies the retained
archive before uploading it. It does not archive older files or change the primary
download. Optional reviewers and deployment restrictions can be set in GitHub;
allow version tags if restricting deployments.

Review the returned Nexus version ID and file listing. An ambiguous upload failure
can cause duplicate versions on retry: inspect Nexus first and retry only failed
jobs while retained artifacts are available (14 days).

Actions artifact downloads wrap the install-ready ZIP; extract that outer wrapper.
GitHub and Nexus publication have not yet been exercised for this repository.

Uploader: https://github.com/Nexus-Mods/upload-action
