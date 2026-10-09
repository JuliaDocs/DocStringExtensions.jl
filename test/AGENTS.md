# Tests

`runtests.jl` loads `reference.jl` and `tests.jl`. `tests.jl` pulls in the fixtures: `TestModule/M.jl` (module `M`), `templates.jl`, and `interpolation.jl`.

## Reference tests

Assert the full output of an abbreviation against a file in `reference_outputs/`:

```julia
str = formatted(DSE.TYPEDEF, doc)
@test_reference ro_path("typedef1.txt") str
```

`formatted(abbr, doc)` returns what `format` writes. `@test_reference` compares it with the file, strips CRLF from both sides, and prints a line diff on mismatch.

- Use a reference test for any multi-line or Markdown output. A substring check such as `occursin("f(x)", str)` passes on output that is broken everywhere else.
- Reuse an existing reference when a test formats the same input as another testset. The `world-age safety` testset does this for every abbreviation it covers.
- Keep short scalar results inline with `==` (`printmethod`, `keywords`, `arguments`). A one-line file hides the expected value from the reader.
- Keep `occursin` where the test asserts which branch was taken, not the rendered text. The `templates` testset checks which `@template` applied by looking for its marker, such as `(TYPES)`.

## Updating references

Run the suite with `DSE_UPDATE_REFERENCES=true` to rewrite every reference the run reaches with the current output. Then read `git diff test/reference_outputs` and confirm you meant every change before committing. A run only rewrites the files for its own Julia version, platform, and word size.

## Output that varies by environment

- Julia version, OS, or word size: keep one reference per variant, suffixed `_pre_110`, `_110_and_later`, `_windows`, `_64bit`, and so on. When two testsets select between the same variants, put the choice in a helper such as `method_lists_reference()` next to `redact_local_info` in `tests.jl`.
- Local paths and commit hashes: `METHODLIST` output links to the source file and the commit. Format it inside `with_test_repo`, which commits `TestModule/M.jl` to a throwaway repo with a fixed remote. Pass the result through `redact_local_info` before comparing.
