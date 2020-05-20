"""
This docstring is attached to the [`Showcase`](@ref) module itself.

The [`EXPORTS`](@ref) abbreviation creates a bulleted list of all the exported names:

$(EXPORTS)

Similarly, the [`IMPORTS`](@ref) abbreviation lists all the imported modules:

$(IMPORTS)

The [`README`](@ref) can be used to include the `README.md` file in a docstring. The content
between the horizontal lines is spliced by the abbreviation:

---

$(README)

---

The [`LICENSE`](@ref) abbreviation can be used in the same way for the `LICENSE.md` file.
"""
module Showcase
using DocStringExtensions

"""
This docstring is attached to an [empty function
definitions](https://docs.julialang.org/en/v1/manual/methods/#Empty-generic-functions-1).
The [`METHODLIST`](@ref) abbreviation allows you to list all the methods though:

$(METHODLIST)
"""
function foo end

"""
This docstring is attached to a method that uses default values for some positional
arguments: `foo(x::Int, y=3)`.

As this effectively means that there are two different methods taking different numbers of
arguments, the [`SIGNATURES`](@ref) abbreviation produces the following result:

$(SIGNATURES)

---

The [`TYPEDSIGNATURES`](@ref) abbreviation can be used to also get the types of the
variables in the function signature:

$(TYPEDSIGNATURES)

---

The [`FUNCTIONNAME`](@ref) abbreviation can be used to directly include the name of the
function in the docstring (e.g. here: $(FUNCTIONNAME)). This can be useful when writing your
own type signatures:

    $(FUNCTIONNAME)(x, ...)
"""
foo(x::Int, y=3) = nothing

"""
A different method for [`$(FUNCTIONNAME)`](@ref). [`SIGNATURES`](@ref) abbreviation:

$(SIGNATURES)

And the [`TYPEDSIGNATURES`](@ref) abbreviation:

$(TYPEDSIGNATURES)
"""
foo(x::AbstractString) = nothing


## Methods with type parameters

"""
A method for [`$(FUNCTIONNAME)`](@ref), with type parameters. Original declaration:

```julia
bar(x::AbstractArray{T}, y::T) where {T <: Integer} = nothing
```

And the result from [`TYPEDSIGNATURES`](@ref) abbreviation:

$(TYPEDSIGNATURES)

For comparison, [`SIGNATURES`](@ref) abbreviation:

$(SIGNATURES)
"""
bar(x::AbstractArray{T}, y::T) where {T <: Integer} = nothing

"""
A method for [`$(FUNCTIONNAME)`](@ref), with type parameters. Original declaration:

```julia
bar(x::AbstractArray{T}, ::String) where {T <: Integer} = x
```

And the result from [`TYPEDSIGNATURES`](@ref) abbreviation:

$(TYPEDSIGNATURES)

For comparison, [`SIGNATURES`](@ref) abbreviation:

$(SIGNATURES)
"""
bar(x::AbstractArray{T}, ::String) where {T <: Integer} = x

"""
A method for [`$(FUNCTIONNAME)`](@ref), with type parameters. Original declaration:

```julia
bar(x::AbstractArray{T}, y::U) where {T <: Integer, U <: AbstractString} = 0
```

And the result from [`TYPEDSIGNATURES`](@ref) abbreviation:

$(TYPEDSIGNATURES)

For comparison, [`SIGNATURES`](@ref) abbreviation:

$(SIGNATURES)
"""
bar(x::AbstractArray{T}, y::U) where {T <: Integer, U <: AbstractString} = 0


"""
The [`TYPEDEF`](@ref) abbreviation includes the type signature:

$(TYPEDEF)

---

The [`FIELDS`](@ref) abbreviation creates a list of all the fields of the type.
If the fields has a docstring attached, that will also get included.

$(FIELDS)

---

[`TYPEDFIELDS`](@ref) also adds in types for the fields:

$(TYPEDFIELDS)
"""
struct Foobar{T <: AbstractString}
    "Docstring for the `x` field."
    x :: Nothing
    y :: T # y is missing a docstring
    "Docstring for the `z` field."
    z :: Vector{T}
end

export foo, Foobar

end
