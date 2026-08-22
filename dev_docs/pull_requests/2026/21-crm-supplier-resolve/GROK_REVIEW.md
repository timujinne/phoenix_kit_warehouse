# PR #21 — Resolve supplier names through Catalogue.resolve_supplier/1

**Reviewed:** 2026-08-22 · **Author:** timujinne · **Verdict:** merged, two
incomplete call sites fixed.

## What actually landed

`resolve_supplier_name/1` in `GoodsReceiptFormLive` and
`SupplierOrderFormLive` now calls `Catalogue.resolve_supplier/1` (the
`Suppliers.resolve/1` facade) instead of `Catalogue.get_supplier/1`. A
local `cat_suppliers` row that projects a CRM party therefore renders the
party's current name; a supplier without a CRM link still resolves to the
local row. The function's `{:ok, %{name: name}} | :error` contract matches
what `Suppliers.resolve/1` actually returns (verified in catalogue 0.18.0).

`resolve_supplier/1` itself has been in catalogue since 0.11.0, so the
then-current `~> 0.13` pin already covered it. The floor was raised to
`~> 0.18` in the PR #23 follow-up for `ItemSelectorModal`, which this
function also rides.

## IMPROVEMENT - HIGH (fixed)

The same stale-name bug the PR fixed on the two *forms* was still live on
the two *indexes*. `SupplierOrderIndexLive.enrich_orders/1` and
`GoodsReceiptIndexLive.enrich_receipts/1` loaded names via
`Catalogue.list_suppliers/0` (local table only) and then
`supplier.name`. A CRM-linked local row therefore still showed its stored
snapshot on the list pages, and a supplier that only exists in CRM was
still unnamed. Both now call `Catalogue.resolve_suppliers/1` (the batch
form of the same API), keyed by the stored uuid so lookup stays a map
get. Locked in by asserting the supplier name on the existing index
"lists existing … by number" tests, plus new form tests that the General
tab renders the resolved name.

## Follow-up (not fixed)

The supplier `<select>` on `SupplierOrderFormLive` is still populated by
`SupplierOrders.list_suppliers/0` → `Catalogue.list_suppliers/0`. Option
labels are the local snapshot, and a CRM-only supplier cannot be chosen
at all. Switching that dropdown to `list_all_suppliers/1` is a different
change: warehouse documents today store a `cat_suppliers` uuid, and
writing a CRM party uuid into that column is a schema/semantics decision,
not a display fix. Left on the record.

## Tests added

- `supplier_order_form_live_test` / `goods_receipt_form_live_test`: the
  form renders the catalogue supplier name.
- `supplier_order_index_live_test` / `goods_receipt_index_live_test`: the
  list row renders it too.
