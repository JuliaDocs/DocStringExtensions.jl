# DocStringExtensions

*Extensions for Julia's docsystem.*

| **Documentation**                                                               | **Build Status**                                                                                |
|:-------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------:|
| [![][docs-stable-img]][docs-stable-url] [![][docs-dev-img]][docs-dev-url] | [![CI][github-action-img]][github-action-url] [![][codecov-img]][codecov-url] |

DocStringExtensions generates parts of a docstring from the code it documents. Interpolate
an abbreviation into a docstring, and it expands to Markdown when the docstring is shown:

```julia
using DocStringExtensions

"""
$(TYPEDSIGNATURES)

Compute the area of a circle with radius `r`.
"""
area(r::Float64) = π * r^2
```

`?area` in the REPL then shows the signature `area(r::Float64) -> Float64` above the summary.

## Installation

```
pkg> add DocStringExtensions
```

## Documentation

- [Stable][docs-stable-url]: the most recent release.
- [Dev][docs-dev-url]: the `master` branch.

## Supported Julia versions

CI tests these Julia versions:

- Linux: 1.0, 1.6, the LTS, the latest release, and nightly.
- macOS and Windows: the latest release.

## Contributing and questions

Open an [issue][issues-url] for bugs and feature requests. Ask questions on the
[Julia Discourse][discourse-url].

[discourse-url]: https://discourse.julialang.org

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://DocStringExtensions.juliadocs.org/dev

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://DocStringExtensions.juliadocs.org/stable

[github-action-img]: https://github.com/JuliaDocs/DocStringExtensions.jl/actions/workflows/ci.yml/badge.svg
[github-action-url]: https://github.com/JuliaDocs/DocStringExtensions.jl/actions/workflows/ci.yml

[codecov-img]: https://codecov.io/gh/JuliaDocs/DocStringExtensions.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaDocs/DocStringExtensions.jl

[issues-url]: https://github.com/JuliaDocs/DocStringExtensions.jl/issues
