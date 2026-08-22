# PR #20 — Declare rustler explicitly so mdex_native force-builds

**Reviewed:** 2026-08-22 · **Author:** timujinne · **Verdict:** merged, no
code changes.

## What actually landed

`mix.exs` now declares `{:rustler, ">= 0.0.0", optional: true}` — the same
line `phoenix_kit`'s own `mix.exs` already carries — and `mix.lock` pins
`rustler` 0.38.0. `MDEX_NATIVE_BUILD=1` forces `mdex_native` (pulled in
through `phoenix_kit`'s `mdex` dep) to build its NIF from source, which
needs `rustler` itself, not just `rustler_precompiled`. Optional
dependencies of dependencies are never resolved, so whichever Mix project
is the *root* has to declare it; this makes *this* repository compile from
a clean checkout under that env var. It does not, and cannot, remove the
need for a host application to declare `rustler` itself.

## Verification

- The declaration matches `phoenix_kit`'s own `mix.exs` (same package, same
  `optional: true`, same `>= 0.0.0` requirement).
- `mix.lock` gained a single `rustler` entry; `rustler_precompiled` was
  already present.
- No `lib/` change. Nothing to regress at runtime.

No findings. Left as-is.
