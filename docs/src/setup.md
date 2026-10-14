# [Setup](@id setup)

This guide adds DocStringExtensions to an existing package and covers the choices that
depend on how the package is laid out.

## Installation

Add DocStringExtensions as a dependency of the package itself. The package builds its
docstrings when it loads, so the docs environment alone is not enough:

```
pkg> add DocStringExtensions
```

## Abbreviations

Load the package in the module whose docstrings use it, before the first such docstring,
then interpolate an abbreviation where its output should go:

```julia
module MyPackage

using DocStringExtensions

"""
$(TYPEDSIGNATURES)

Compute the area of a circle with radius `r`.
"""
area(r::Float64) = π * r^2

end
```

The [examples](@ref examples-functions) show what each abbreviation renders.

## Templates

To add the same abbreviations to every function or type docstring, define a
[`@template`](@ref). A template applies only to docstrings that come after it, so put it
before the definitions it should document:

```julia
module MyPackage

using DocStringExtensions

@template (FUNCTIONS, METHODS, MACROS) = """
    $(TYPEDSIGNATURES)
    $(DOCSTRING)
    """

@template TYPES = """
    $(TYPEDEF)
    $(DOCSTRING)
    $(TYPEDFIELDS)
    """

@template ABSTRACTTYPES = """
    $(TYPEDEF)
    $(DOCSTRING)
    $(SUBTYPES)
    """

include("shapes.jl")
include("areas.jl")

end
```

A template applies only in the module that defines it. If the package has submodules, copy
the templates into each one:

```julia
module Shapes

using DocStringExtensions
import ..MyPackage

@template (FUNCTIONS, METHODS, MACROS) = MyPackage
@template (TYPES, ABSTRACTTYPES) = MyPackage

end
```

The [template examples](@ref examples-templates) show the rendered result, including a
submodule without a template.

## Documenter

Abbreviations expand when Documenter renders a docstring, so a `@docs` or `@autodocs` block
needs no extra setup.

[`EXPORTS`](@ref) and [`PUBLIC`](@ref) write each name as a Documenter `@ref` link.
Documenter fails the build when a link has no target, so every listed name needs its
docstring included somewhere in the manual.

## [Rendering settings](@id setup-rendering)

Two environment variables change how signatures render. They suit a reader's own startup
file or shell profile, since they apply to the docstrings of every package alike. A package
sets neither. A Documenter build renders with the values in the environment that runs
`docs/make.jl`.

| Variable                              | Default | Effect                                                   |
|:------------------------------------- |:------- |:-------------------------------------------------------- |
| `DOCSTRINGEXTENSIONS_RETURN_ARROW`    | `->`    | The arrow before a return type, such as `→`.             |
| `DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH` | `60`    | The longest one-line signature, in characters. A longer one prints one argument per line. |

```julia
ENV["DOCSTRINGEXTENSIONS_RETURN_ARROW"] = "→"
ENV["DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH"] = "92"
```

A docstring reads them the first time it is shown, and Julia keeps the result for the rest
of the session. Set them before showing any docstring, so a change reaches every one.

## Function arguments

No abbreviation documents the arguments of a function. [`FIELDS`](@ref) and
[`TYPEDFIELDS`](@ref) work only on the fields of a type. List arguments by hand under an
`# Arguments` heading.
