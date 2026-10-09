# DocStringExtensions.jl

DocStringExtensions adds abbreviations and templates to Julia's docsystem. An abbreviation such as `SIGNATURES` or `FIELDS` is interpolated into a docstring and expands into generated Markdown when the docstring is rendered.

## Layout

- `src/abbreviations.jl` defines each abbreviation as a subtype of `Abbreviation`, a `const` instance (`TYPEDEF`, `METHODLIST`, ...), and a `format(abbr, buf, doc)` method that writes its Markdown to `buf`.
- `src/templates.jl` implements `@template`, which wraps every docstring of a given kind in a module.
- `src/utilities.jl` holds the method, signature, and source-URL introspection that the abbreviations call.
- `docs/` is the Documenter site. `docs/make.jl` builds it.
- `test/` holds the suite. `test/AGENTS.md` covers how it is written.

## Constraints

- CI runs Julia 1.0, the LTS, the latest release, and nightly. Code in `src/` and `test/` must parse and run on 1.0, so check any syntax or Base function newer than that against the floor.
- The package leans on undocumented Base internals (`Base.kwarg_decl`, method table fields, binding partitions on 1.12+). The `Base assumptions` testset in `test/tests.jl` records each one. Add a case there when the code starts relying on another.
- `format` methods can run in a stale world during macro expansion. Wrap binding lookups such as `Docs.resolve` and `methods` in `Base.invokelatest`, as the existing `format` methods do.

## Running tests

```bash
julia --project <<'EOF'
using TestEnv; TestEnv.activate()
include("test/runtests.jl")
EOF
```

`Pkg.test()` runs the same suite in a fresh sandbox. Use it as the final check before a commit.
