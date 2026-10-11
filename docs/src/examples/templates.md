# [Templates](@id examples-templates)

```@meta
CurrentModule = Examples
```

The docstrings for `@template` and `DOCSTRING` are in the [reference](@ref reference-templates).

[`@template`](@ref) wraps every later docstring of a given kind in a module, so the
abbreviations are written once. [`DOCSTRING`](@ref) marks where each original docstring goes.

  * A template applies only to docstrings that come after it, so define templates before
    the definitions that use them.
  * A template applies only in the module that defines it. A submodule needs its own, or a
    copy made with `@template CATEGORY = ParentModule`.

```@eval
Main.example_source("templates.jl")
```

The docstrings render as:

```@docs
Geometry.unit_circle
Geometry.Circle
Geometry.area
Geometry.Plain.perimeter
Geometry.Copied.diameter
```
