# PR #23 — Route item-adding through the catalogue's ItemSelectorModal

**Reviewed:** 2026-08-22 · **Author:** timujinne · **Verdict:** merged,
several host-wiring gaps fixed.

## What actually landed

Warehouse's `add_picker/1` (tree/search/add UI that never touched a
warehouse-specific field) is gone. Internal orders, stocktakes, and
transfers now mount `PhoenixKitCatalogue.Web.Components.ItemSelectorModal`
and handle its documented contract:

- `handle_info({:items_selected, %{picks: picks}}, socket)` — each pick
  (uuid + Decimal qty) becomes a new line seeded with that quantity;
  re-adding an already-present item is a no-op.
- `handle_info({:item_selector_closed, %{id: _}}, socket)` — resets the
  `:if` assign so the next open remounts clean.

`warehouse_browser.ex` dropped ~230 lines. Tests were rewritten for the
new contract rather than stacked on the old picker-UI assertions. The
`PGDATABASE` override in `config/test.exs` is a CI-environment helper,
unrelated to the modal, and is fine.

The merge diff relative to `main` does **not** include a catalogue pin
bump. The PR body said `mix.exs` still required `~> 0.13` "deliberately —
there's no released version to bump the floor to yet." Catalogue 0.18.0
(ItemSelectorModal) is on Hex now; this repo's lockfile already resolved
it via the later `lib upgrades` commit.

## BUG - HIGH (fixed)

`pk_dep(:phoenix_kit_catalogue, "~> 0.13")` still admitted 0.13–0.17. Those
releases have no `ItemSelectorModal`. A host whose resolution landed below
0.18 would fail to compile this package — the same class of defect PR #12
fixed for core. Floor raised to `~> 0.18`, with
`test/catalogue_pin_conformance_test.exs` pinning the range.

## BUG - MEDIUM (fixed)

`InventoryFormLive.selected_items/1` only matched
`%{"counted_quantity" => %Decimal{}}`. Lines round-tripped through JSONB
come back as strings (or numbers). Opening the modal on a saved stocktake
therefore handed the component `%{}`, so already-counted items appeared
pickable again (confirm still no-op'd via the uuid dedup, but the tray
lied). All three LiveViews now coerce through `StockLedger.to_decimal/1`.
Locked in with a test that creates a draft whose `counted_quantity` is
the string `"5"` and asserts the modal tray shows "1 item".

## BUG - MEDIUM (fixed)

`Catalogue.get_item!/1` in `add_item_to_lines/3` would crash the LiveView
if a pick's uuid was gone between confirm and `handle_info` (deleted row,
stale payload). Now `Catalogue.get_item/1`; a missing item is skipped.
Locked in on all three form tests.

## IMPROVEMENT - HIGH (fixed)

The modal was mounted with `scope={%{}}`, no `locale`, and the default
`qty_precision: 0`:

- Empty scope lists every non-deleted item, including inactive /
  discontinued. Warehouse `seed_lines/2` already filters `status ==
  "active"`. Scope is now `%{statuses: ["active"]}`.
- Locale defaulted to `Gettext.get_locale(PhoenixKitCatalogue.Gettext)`,
  not the warehouse LiveView's `@locale`. Passed through.
- Warehouse quantity inputs use `step="any"`. Precision 0 rounded every
  pick to a whole number. Now `qty_precision={6}`, matching the modal's
  own parse ceiling.

`open_item_selector` also had no posted/draft guard (the old
`open_add_picker` didn't either). A crafted event could mount the
component on a posted document; confirm still no-op'd. The open event now
uses the same predicate as confirm.

## NITPICK (fixed)

The new tests `send/2`'d into the LiveView and then `:timer.sleep(50)`
before `:sys.get_state/1`. `get_state` is a synchronous call; the sleep
did nothing except slow the suite. Removed.

## Follow-up (not fixed)

Confirming the modal with a preselected item whose qty the user changed
in the tray is still a no-op on the host side — `add_item_to_lines/3`
dedups by uuid and does not update quantity. That matches the old
add-picker ("already present → disabled") and is what the tests lock.
Updating an existing line's qty from the modal would be a new behaviour,
not a restoration.

Goods receipts / issues / supplier orders never had `add_picker/1`; they
import lines from upstream documents. Out of scope.
