# Local monorepo development: resolve in-repo packages by bare module name
# (e.g. `import rui_core`) before any of them is published to Nimble.
#
# This file lives at the repo root, OUTSIDE every `packages/<name>` prefix, so
# `git subtree split --prefix=packages/<name>` never copies it into the
# standalone repos. There, the per-package .nimble `requires` resolve the deps.
switch("path", "packages/rui_core/src")
switch("path", "packages/rui_hittest/src")
switch("path", "packages/rui_events/src")
switch("path", "packages/rui_drawing/src")
switch("path", "packages/rui_scripting/src")
switch("path", "packages/rui_widgets/src")
switch("path", "packages/rui/src")
