module ConstructorsTestModule

using DocStringExtensions
# Inferred return types differ between Julia versions.
import DocStringExtensions: TypedMethodSignatures

include("keywords_macro.jl")

"""
$(SIGNATURES)
"""
struct Plain
    a::Float64
    b
end

"""
$(TypedMethodSignatures(returns = false))
"""
struct Typed
    a::Float64
    b
end

"""
$(TypedMethodSignatures(returns = false))
"""
struct Parametric{T}
    x::T
end

"""
$(SIGNATURES)
"""
struct Inner
    x::Float64
    Inner(x::Float64) = new(x)
    function Inner()
        return new(0.0)
    end
end

Inner(s::String) = Inner(1.0)

"""
$(SIGNATURES)
"""
Base.@kwdef struct Options
    retries::Float64 = 3.0
    name::String
end

"""
$(TypedMethodSignatures(returns = false))
"""
Base.@kwdef struct TypedOptions
    retries::Float64 = 3.0
    name = "a"
end

"""
$(SIGNATURES)
"""
Base.@kwdef struct EmptyOptions end

macro identity(ex)
    return esc(:(Base.@__doc__ $ex))
end

"""
$(SIGNATURES)
"""
@identity struct Wrapped
    a::Float64
    b::Float64
end

Wrapped(; a = 1.0, b = 2.0) = Wrapped(a, b)

"""
$(SIGNATURES)
"""
@keywords struct Generated
    a::Float64 = 1.0
    b::Float64 = 2.0
end

"""
$(SIGNATURES)
"""
struct Empty end

"""
$(SIGNATURES)
"""
abstract type Abstract end

"""
$(METHODLIST)
struct `Scaled`
"""
struct Scaled{T}
    x::T
    Scaled{T}(x::Int) where {T} = new{T}(T(x))
end
Scaled(x::Float64) = Scaled{Float64}(1)

module Templated

    using DocStringExtensions

    @template TYPES =
    """
    $(SIGNATURES)

    $(DOCSTRING)
    """

    "type `Point`"
    struct Point
        x::Float64
    end

    Point() = Point(0.0)

end

end
