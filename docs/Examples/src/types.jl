"""
[`TYPEDEF`](@ref) prints the type's header:

$(TYPEDEF)

---

[`FIELDS`](@ref) lists the fields, with the docstring of each field that has one:

$(FIELDS)

---

[`TYPEDFIELDS`](@ref) adds the field types:

$(TYPEDFIELDS)
"""
struct Foobar{T <: AbstractString}
    "Docstring for the `x` field."
    x :: Nothing
    y :: T # y has no docstring
    "Docstring for the `z` field."
    z :: Vector{T}
end

"""
[`SIGNATURES`](@ref) lists the constructors that the struct definition creates:

$(SIGNATURES)

---

A field given a default with `Base.@kwdef` shows its default in [`FIELDS`](@ref) and
[`TYPEDFIELDS`](@ref):

$(TYPEDFIELDS)
"""
Base.@kwdef struct Settings
    "Seconds to wait before giving up."
    timeout::Float64 = 30.0
    retries::Int = 3
    name::String
end

"""
An interface for shapes. [`SUBTYPES`](@ref) lists the types that implement it:

$(SUBTYPES)
"""
abstract type Shape end

"A circle."
struct Circle <: Shape end

"A square."
struct Square <: Shape end
