"""
The singleton type for [`DOCSTRING`](@ref) abbreviations.
"""
struct DocStringTemplate <: Abbreviation end

"""
An [`Abbreviation`](@ref) that marks where a [`@template`](@ref) places the original
docstring. Every template must contain it.

# Examples

```jldoctest
julia> module Shapes
       using DocStringExtensions
       @template (FUNCTIONS, METHODS) = \"""
           \$(DOCSTRING)
           Part of the `Shapes` module.
           \"""
       "Compute the area of a square."
       area(side) = side^2
       end;

julia> @doc Shapes.area
  Compute the area of a square. Part of the Shapes module.
```

!!! warning

    Use `DOCSTRING` only in templates. Showing an ordinary docstring that contains it
    throws an error.
"""
const DOCSTRING = DocStringTemplate()

# NOTE: no `format` needed for this 'mock' abbreviation.

is_docstr_template(::DocStringTemplate) = true
is_docstr_template(other) = false
