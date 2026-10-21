# DocStringExtensions.jl

DocStringExtensions adds abbreviations and templates to Julia's docsystem. An abbreviation such as `SIGNATURES` or `FIELDS` is interpolated into a docstring and expands into generated Markdown when the docstring is rendered.

## Layout

- `src/interface.jl` declares `Abbreviation`, the `format` fallback, and the `interpolation` extension point.
- `src/abbreviations/` holds one file per abbreviation, named after its `const` (`typedef.jl` for `TYPEDEF`). Each defines a subtype of `Abbreviation`, the `const` instance, and a `format(abbr, buf, doc)` method that writes its Markdown to `buf`. A typed variant shares its untyped twin's file, and `module_names.jl` and `package_files.jl` each hold two abbreviations that share a `format`.
- `src/definitions.jl` reads the documented expression: argument defaults, field defaults, and where a struct definition ends.
- `src/methods.jl` finds and groups the methods a docstring documents. It also reads what Julia records about each method, such as its keywords and inferred return type.
- `src/settings.jl` reads the environment variables a reader sets to change how docstrings render, such as the return arrow.
- `src/type_text.jl` writes a type as its source writes it, with each `<:T` parameter written as its bound or as the `const` alias that gives it. Signatures, field lists and `TYPEDEF` print types through it.
- `src/printmethod.jl` renders a method signature for `SIGNATURES`, `TYPEDSIGNATURES` and the method lists.
- A helper with a single caller, including a compat shim for an older Julia, sits in its caller's file.
- `src/templates.jl` implements `@template`, which wraps every docstring of a given kind in a module.
- `src/hook.jl` replaces `Core.atdoc` to capture the documented expression for `interpolation` and to resolve templates.
- `src/DocStringExtensions.jl` includes the files so that each loads after any type its fields or method signatures name.
- `docs/` is the Documenter site. `docs/make.jl` builds it.
- `test/` holds the suite. `test/AGENTS.md` covers how it is written.
- `CHANGELOG.md` follows Keep a Changelog. Record user-facing changes under `Unreleased`, with issue and PR links written inline.

## Constraints

- CI runs Julia 1.0, the LTS, the latest release, and nightly. Code in `src/` and `test/` must parse and run on 1.0, so check any syntax or Base function newer than that against the floor.
- The package leans on undocumented Base internals (`Base.kwarg_decl`, method table fields, binding partitions on 1.12+). The `Base assumptions` testset in `test/base_assumptions.jl` records each one. Add a case there when the code starts relying on another.
- A user-facing change updates every page that shows the feature, in the same commit as the code. Check the docstring, the `Examples` module in `docs/Examples/src/` and its page in `docs/src/examples/`, `docs/src/setup.md`, and `CHANGELOG.md`. Search `docs/` for the names the change touches, then build the docs as CI does. The build runs the doctests and fails on a broken `@ref`.
- From Julia 1.6 the package runs interpreted (`@compiler_options compile = min` in `src/DocStringExtensions.jl`), and it ships no precompile workload, which would slow every dependent's load. Interpreted code costs nothing to compile, but a closure or generator handed to Base, as in `map`, `filter`, `any`, `sort!` with `by` or a comprehension, compiles a new specialization of the Base function on the first render. Write those as loops.
- `format` methods can run in a stale world during macro expansion. Wrap binding lookups such as `Docs.resolve` and `methods` in `Base.invokelatest`, as the existing `format` methods do.

## Running tests

```bash
julia --project <<'EOF'
using TestEnv; TestEnv.activate()
include("test/runtests.jl")
EOF
```

`Pkg.test()` runs the same suite in a fresh sandbox. Use it as the final check before a commit.

## Formatting

Runic formats `src/` and `test/`. The CI `Format` job runs the check and fails on any unformatted file.

```bash
just fmt        # Format in place
just fmt-check  # Check without changing files, as CI does
```

## Building docs

```bash
julia --project=docs docs/instantiate.jl
julia --project=docs docs/make.jl
```

`docs/Project.toml` takes DocStringExtensions from this checkout and Documenter from `docs/deps/Documenter` through `[sources]`. Documenter depends on DocStringExtensions, so `docs/instantiate.jl` clones the latest Documenter there and widens its compat bound when it leaves out this version.
