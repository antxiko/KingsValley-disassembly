# Getting started

This repository holds the commented disassembly of **King's Valley** (Konami,
1985), the 16 KB **RC-727** cartridge for the MSX1.

The ROM is **not distributed here**. You need to put it in the root of the
repository as `kingsvalley.rom`. To check it is the same one:

```
shasum -a 256 kingsvalley.rom
a8f807a0be90db6a01c43a948215a8761d1d7b92358279d6f2ce2dcfefab5d73
```

## What `make` does

```
make listado    builds src/kingsvalley.asm from the trace and the notes
make verify     reassembles the listing and compares it to the ROM, byte for byte
make sanity     the four checks reassembling does NOT cover
make densidad   counts how much of the listing is commented
make imagenes   draws the declared graphic blocks, so you can look at them
make web        builds the bilingual site in docs/
```

Plain `make` runs `listado`, `verify`, `sanity` and `test`.

## Why `verify` is the test that matters

A disassembly can be written many ways, and almost all of them are wrong in
some way that does not show. The one test that admits no argument is to
reassemble the listing and check that **exactly the same ROM** comes back: the
16,384 bytes, in the same order, with the same sha256.

That is what `make verify` does, and it has been run after every batch of work.
If it ever fails, the listing is wrong, however nicely it reads.

## What reassembling does not cover

Identical bytes say nothing about whether we have **understood** them. A data
block read as if it were code produces the same binary and a lie in the
listing. So `make sanity` runs four separate checks:

- **`check_trace.py`**: nothing declared as data in the `.nocode` may have come
  out traced as code.
- **`check_datos_como_codigo.py`**: cross-checks the 110 declared data regions
  against the real trace.
- **`check_entradas.py`**: no entry point may land inside a data region.
- **`presupuesto.py`**: not one byte of the cartridge left unassigned. This is
  the demanding one, and today it passes: **0 bytes unexplained**.

## The files edited by hand

Only three, all in `src/`:

- **`kingsvalley.entries`** — the entry points static tracing cannot work out
  on its own: the header's `INIT`, the interrupt hook, the eleven destinations
  of the task table, and the loop closers the cartridge pushes onto the stack.
  Each with its justification written beside it.
- **`kingsvalley.nocode`** — the regions the tracer must not keep reading as
  code, with the reason for each.
- **`kingsvalley.notes`** — the `L` directives (a routine's name and
  description), `C` (a comment on one line) and `D`/`F` (a data block, its name
  and the width of its structure). It is the big file, and where everything
  understood actually lives.

`src/kingsvalley.asm` is **generated**: never edited by hand.

## The pictures

Not one picture on the site is an emulator capture. They are all drawn by
`tools/pantallas.py` from the bytes of the ROM, by running in Python the two
script interpreters the Z80 runs. See [The code](THE-CODE.html) for how they
work.
