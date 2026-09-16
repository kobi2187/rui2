# Module summaries

One file per module, mirroring the source tree with the `.nim` extension
dropped: `packages/rui_widgets/src/virtual_rows.nim` →
`thoughts/module_summaries/packages/rui_widgets/src/virtual_rows.md`.

**Read these before reading source.** Each one carries the module's purpose,
its public interface, the minimal call sequence to use it correctly, and the
circumstances that produced it. Only open the source when you need an
implementation detail the summary does not cover.

Pure re-export aggregators (`basic.nim`, `containers.nim`, `data.nim`,
`dialogs.nim`, `input.nim`, `menus.nim`, `modern.nim`, `rui_widgets.nim`) have
no summary — they import and export their directory and nothing else.

## Checking for staleness

```bash
cd /home/kl/prog/rui2
find packages -name '*.nim' | while read src; do
  summary="thoughts/module_summaries/${src%.nim}.md"
  if [ -f "$summary" ] && [ "$src" -nt "$summary" ]; then
    echo "STALE:   $summary"
  elif [ ! -f "$summary" ]; then
    echo "MISSING: $summary"
  fi
done
```

Regenerate the entries you actually touch; there is no need to clear the whole
backlog in one go.

## Layout

- `packages/rui_widgets/src/` — the widgets, plus the shared support modules
  (`virtual_rows`, `list_input`) that several of them sit on.
- `packages/rui_core/src/`, `packages/rui/src/`, `packages/rui_hittest/src/` —
  only the modules touched so far, not the whole package.
</content>
