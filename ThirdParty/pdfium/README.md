# PDFium (pinned)

This directory is managed by task P0-03 (PDFium Build Integration).

Files expected here:
- PINNED_REVISION — a single-line file containing the PDFium commit hash or tag to build.
- PDFium.xcframework — the built binary framework (store via Git LFS, do not commit large binaries directly).

Build recipe: Scripts/build-pdfium.sh (template). Edit PINNED_REVISION and run the script to produce an xcframework at ThirdParty/pdfium/PDFium.xcframework.

Note: the provided script is a template illustrating the workflow. The actual build uses PDFium's gn + ninja flow and must be adapted to the pinned revision and the CI environment. See ADR-001 for upgrade playbook and security requirements.
