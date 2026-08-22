# PR #22 — Fix stale admin_tabs test: Tab.visible semantics drift + tab count

**Reviewed:** 2026-08-22 · **Author:** timujinne · **Verdict:** merged, one
lock added.

## What actually landed

Core 2.6.0 changed `Tab.visible`'s default from `true` to `nil` ("auto":
visible unless the path is parameterized). This module's 8 top-level admin
tabs never set `visible:` explicitly, so they went from a plain `true` to
`nil`. Nothing in `lib/` reads the raw field — sidebar rendering goes
through core's `Tab.visible?/2` — so the rendered UI was never affected.
Only `test/phoenix_kit_warehouse_test.exs` was, because
`Enum.reject(tabs, & &1.visible)` treated every `nil` as hidden.

The PR sets `visible: true` on those 8 tabs (the documented way to force a
nav entry into the sidebar) and updates the hardcoded tab count 37 → 38
(the Turnover tab, unrelated to the `visible` issue).

Setting `visible: true` on unparameterized paths is redundant with the new
auto default, but it is the right explicit contract: these entries are
navigation, not routes, and a future path that gains a parameter would
otherwise silently drop out of the sidebar.

## IMPROVEMENT - MEDIUM (fixed)

The test still only asserted `visible == true` on the Transfers tab and
`length(hidden) == 30`. A later tab added without `visible:` would have
failed the hidden-count assertion *and* `Enum.all?(hidden, &(&1.visible ==
false))`, but only after mixing `nil` into the "hidden" list — a confusing
failure. Added an explicit pin that no `admin_tabs/0` entry leaves
`visible` unset.

## Notes

The magic `38` / `30` counts stay. They exist to catch accidental tab
additions, which is the point of a hardcoded length. Not worth
re-deriving from `admin_tabs/0` itself.
