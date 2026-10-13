"""
The type for [`NOTEMPLATE`](@ref) abbreviations.

`TemplateOverride(category)` applies the module's [`@template`](@ref) for `category` to the
docstring it appears in, in place of the template for the documented object's own category.
`category` is one of the categories `@template` accepts, and the module must define a
template for it before the docstring.

$(:FIELDS)
"""
struct TemplateOverride <: Abbreviation
    category::Union{Symbol, Nothing}
    TemplateOverride(category::Symbol) = new(checked_category(category))
    TemplateOverride(::Nothing) = new(nothing)
end

"""
An [`Abbreviation`](@ref) that stops the module's [`@template`](@ref) applying to the
docstring it appears in. It prints nothing.

# Examples

```jldoctest
julia> module Shapes
       using DocStringExtensions
       @template (FUNCTIONS, METHODS) = \"""
           \$(TYPEDSIGNATURES)
           \$(DOCSTRING)
           \"""
       \"""
       Compute the area of a square.
       \$(NOTEMPLATE)
       \"""
       area(side::Int) = side^2
       end;

julia> @doc Shapes.area
  Compute the area of a square.
```

!!! tip "Using Another Category's Template"
    To apply the module's template for another category in place of skipping the template,
    use `\$(DocStringExtensions.TemplateOverride(:DEFAULT))` with that category.
"""
const NOTEMPLATE = TemplateOverride(nothing)

format(::TemplateOverride, buf, doc) = nothing
