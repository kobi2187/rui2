# Splitting packages into their own repositories

RUI2 is a monorepo of 7 packages under `packages/`. Each is laid out so that
`git subtree split --prefix=packages/<name>` produces a clean standalone repo
whose root already contains `<name>.nimble`, `README.md`, and `src/`.

The root `config.nims` (which wires the packages together for local development)
lives **outside** every `packages/<name>` prefix, so it is never copied into a
split repo. In a standalone repo, the per-package `.nimble` `requires` (declared
as git URLs) resolve the inter-package dependencies instead.

## Dependency order

Split/publish in this order so each dependency exists before its dependents
reference it:

```
rui_core
  ├─ rui_hittest      (→ rui_core)
  ├─ rui_events       (→ rui_core)
  ├─ rui_drawing      (→ rui_core)
  ├─ rui_scripting    (→ rui_core)
  │     rui_widgets   (→ rui_core, rui_drawing)
  └─ rui              (→ all of the above)
```

`rui_hittest`, `rui_events`, `rui_drawing`, `rui_scripting` are mutually
independent. Keep `rui_core` first, `rui_widgets` after `rui_drawing`, `rui` last.

## Per-package commands

You have the `gh` CLI and push access. For each package, in dependency order:

```bash
# from the monorepo root, on a clean committed tree
PKG=rui_core   # then rui_hittest, rui_events, rui_drawing, rui_scripting, rui_widgets, rui

git subtree split --prefix=packages/$PKG -b split/$PKG
gh repo create kobi2187/$PKG --public
git push https://github.com/kobi2187/$PKG split/$PKG:main

# tag a release so downstream `requires "... >= 0.2.0"` resolves
git clone https://github.com/kobi2187/$PKG /tmp/$PKG
git -C /tmp/$PKG tag v0.2.0
git -C /tmp/$PKG push origin v0.2.0
```

Tag each package **before** splitting the package that depends on it.

## Notes

- The monorepo keeps full history; splits are derived. Re-run
  `git subtree split` after future monorepo commits and push the updated
  `split/<name>` branch to refresh a standalone repo.
- After publishing, you can simplify each `.nimble` from the git-URL form
  (`requires "https://github.com/kobi2187/rui_core >= 0.2.0"`) to the bare
  registry form (`requires "rui_core >= 0.2.0"`) once the packages are added to
  the Nimble package directory.
- Choose and add a license to each package before publishing (the `.nimble`
  files currently carry a `# license` TODO).
