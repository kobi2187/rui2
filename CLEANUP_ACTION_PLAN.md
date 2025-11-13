# RUI2 Cleanup Action Plan

**Date:** 2025-11-12
**Based on:** Codebase audit + modification times

## Understanding the Codebase

**Active Core:** 31 files imported by rui.nim
**Library Code:** Widgets, drawing functions, layout - available but not auto-imported (user choice)
**Examples:** Standalone test files (not part of library)

## Critical Version Conflicts to Resolve

### 1. DSL System - DECISION NEEDED

**Current active:** `widget_dsl_v2.nim` (865 lines, modified Nov 12)
**Alternatives:**
- `widget_dsl.nim` (281 lines, modified Nov 12) - OLD
- `widget_dsl_v3.nim` (252 lines, modified Nov 10) - NEWER, cleaner
- `widget_dsl_helpers.nim` (371 lines) - For v3

**Status:** V2 is actively used. V3 exists and is simpler but not integrated.

**Action:**
- [ ] Read widget_dsl_v3.nim to understand improvements
- [ ] If v3 is better: migrate widgets from v2 to v3
- [ ] If v2 is staying: move v3 to experimental/ or delete
- [ ] Delete old widget_dsl.nim (unversioned, outdated)

---

### 2. Event Manager - DECISION NEEDED

**Current active:** `event_manager.nim` (320 lines, modified Nov 6)
**Alternative:** `event_manager_refactored.nim` (332 lines, modified Nov 10)
**Helper:** `event_manager_helpers.nim` (277 lines, modified Nov 10)

**Status:** Refactored version is NEWER but not used.

**Action:**
- [ ] Compare event_manager.nim vs event_manager_refactored.nim
- [ ] If refactored is better: replace in rui.nim, test, delete old
- [ ] If current is better: delete refactored version
- [ ] Integrate or delete event_manager_helpers.nim

---

### 3. Widget Versions - Clear Naming

**Conflicts found:**
```
widgets/basic/button.nim vs button_v2.nim
widgets/basic/label.nim vs widgets/primitives/label.nim
widgets/containers/vstack.nim vs vstack_v2.nim
widgets/containers/hstack.nim vs hstack_v2.nim
```

**All modified:** Nov 12 03:46 (sed replacements today)

**Action:**
- [ ] Verify v2 widgets compile and work
- [ ] Move old versions to deprecated/ folder:
  - widgets/basic/button.nim
  - widgets/basic/label.nim (duplicate of primitives/label)
  - widgets/containers/vstack.nim
  - widgets/containers/hstack.nim
- [ ] Or delete if no historical value

---

### 4. Missing from rui.nim Import

**Recently created but not imported:**
- `drawing_primitives/widget_primitives.nim` (created Nov 12, 03:12)
  - Theme-aware widget drawing functions
  - Should be in rui.nim drawing layer

**Action:**
- [ ] Add to rui.nim:
  ```nim
  import drawing_primitives/widget_primitives
  export widget_primitives
  ```
- [ ] Test compilation: `nim c rui.nim`

---

## Known Compilation Issues to Fix

From testing session, these have errors:

### Widgets with Issues

1. **spinner.nim** - `fmt()` type mismatch (not related to Link changes)
2. **scrollbar.nim** - Missing `repeat()` import
3. **tabcontrol.nim** - Wrong syntax (onTabChanged as prop instead of action)

**Action:**
- [ ] Fix spinner.nim fmt() call
- [ ] Add strutils import to scrollbar.nim
- [ ] Fix tabcontrol.nim to use actions: block

---

## Accidental Backporting Needed

**Problem:** Today's sed replacements (Nov 12 03:46) changed ALL widgets, including old versions.

**Files affected:** All widgets/* modified at same timestamp

**Action:**
- [ ] Check if sed accidentally broke old widget versions
- [ ] If old versions still needed for migration, restore from git
- [ ] If old versions not needed, mark for deletion

---

## Files to Review for Backporting

**Recently created/modified infrastructure (Nov 10-12):**

### Potentially Good Code Not in Active System

1. **widget_dsl_v3.nim** (Nov 10) - Cleaner DSL
2. **event_manager_refactored.nim** (Nov 10) - Improved event manager
3. **widget_primitives.nim** (Nov 12) - Theme-aware drawing
4. **focus_manager.nim** (Nov 12) - ✓ Already integrated

### Helper/Support Code

5. **widget_dsl_helpers.nim** (Nov 10) - For v3
6. **event_manager_helpers.nim** (Nov 10) - For refactored
7. **app_helpers.nim** (Nov 10) - Unknown purpose
8. **pango_helpers.nim** (Nov 10) - Pango integration

**Action:**
- [ ] Review each file's purpose
- [ ] Integrate useful code into active system
- [ ] Document or delete experimental code

---

## Cleanup Categories

### A. Delete Immediately (Garbage Files)

```
drawing_primitives/fsdfsd.nim  - Random filename, junk
```

### B. Move to deprecated/ (Old Versions)

```
core/widget_dsl.nim              - OLD unversioned DSL
widgets/basic/button.nim         - OLD (using button_v2)
widgets/basic/label.nim          - Duplicate (using primitives/label)
widgets/containers/vstack.nim    - OLD (using vstack_v2)
widgets/containers/hstack.nim    - OLD (using hstack_v2)
```

### C. Move to experimental/ (Unused but Potentially Useful)

```
core/widget_dsl_v3.nim (if not migrating to it)
managers/event_manager_refactored.nim (if not adopting)
drawing_primitives/theme_loader.nim (JSON/YAML themes)
drawing_primitives/theme_load.nim
pango_integration/* (if not using Pango yet)
```

### D. Concept/Idea Files (Move to docs/ or delete)

```
drawing_primitives/base_themes_idea.nim
drawing_primitives/treelist_concept.nim
```

### E. Keep in Library (Not imported but available)

All other widgets - these are library code for users:
- widgets/data/*
- widgets/dialogs/*
- widgets/menus/*
- widgets/modern/*
- widgets/input/*

---

## Systematic Cleanup Process

### Phase 1: Resolve Critical Decisions (This Session?)

1. DSL version (v2 vs v3)
2. Event manager (current vs refactored)
3. Add widget_primitives to rui.nim

### Phase 2: Fix Compilation (Next Session)

1. Fix known widget errors (spinner, scrollbar, tabcontrol)
2. Test all widgets in basic.nim
3. Test all widgets in containers.nim
4. Fix any issues from sed replacements

### Phase 3: Structural Cleanup

1. Create deprecated/ folder
2. Move old versions
3. Create experimental/ folder
4. Move unused refactored code
5. Delete garbage files

### Phase 4: Library Organization

1. Add more widgets to aggregators as they're tested
2. Document which widgets are production-ready
3. Create widget status matrix

---

## Compilation Test Strategy

**Single test target:** `nim c rui.nim`

**When adding untested widgets:**
1. Add to aggregator (basic.nim, containers.nim, etc.)
2. Test: `nim c rui.nim`
3. If error: fix widget, re-test
4. If success: widget is production-ready

**Current status:**
- ✓ rui.nim compiles
- ✓ 31 core files working
- ✓ 7 basic widgets working
- ✓ 3 container widgets working
- ✓ 3 primitive widgets working

---

## Priority Actions for Next Session

### HIGH PRIORITY

1. **Add widget_primitives.nim to rui.nim** - Just created, should be integrated
2. **Fix 3 known widget errors** - spinner, scrollbar, tabcontrol
3. **Decide DSL version** - Are we keeping v2 or migrating to v3?

### MEDIUM PRIORITY

4. **Event manager decision** - Current vs refactored
5. **Move old widget versions** - To deprecated/
6. **Delete fsdfsd.nim** - Garbage file

### LOW PRIORITY

7. **Organize experimental code** - Create experimental/ folder
8. **Add more widgets to aggregators** - As needed by users
9. **Document widget status** - Which are tested/ready

---

## Success Criteria

After cleanup:
- [ ] `nim c rui.nim` compiles without errors
- [ ] All actively imported files are latest versions
- [ ] Old versions clearly marked (deprecated/ folder)
- [ ] Experimental code clearly marked (experimental/ folder)
- [ ] No version confusion (button.nim vs button_v2.nim resolved)
- [ ] Documentation reflects actual codebase structure

---

## Notes

- **Don't delete examples** - They're standalone tests, keep as-is
- **Don't delete library widgets** - Even if not imported, users can import them
- **Focus on core system** - That's what rui.nim imports
- **Test after each change** - `nim c rui.nim` is fast

---

## Questions to Answer

1. **DSL v3:** Is it worth migrating from v2 to v3? What are the benefits?
2. **Event manager refactored:** What improvements does it have?
3. **Hit-testing:** Why isn't it integrated? Is it needed for mouse events?
4. **Layout system:** Where does layout calculation happen? In widgets or separate module?
5. **Pango integration:** Are we using it or sticking with basic text rendering?
