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
