module ConstructorsTestModule

using DocStringExtensions
# Inferred return types differ between Julia versions.
import DocStringExtensions: TypedMethodSignatures

# Like Parameters.jl's `@with_kw`, defines the keyword constructor at a line of this macro.
macro keywords(ex)
    local name = ex.args[2]
    local fields = filter(f -> Meta.isexpr(f, :(=)), ex.args[3].args)
    local keywords = [Expr(:kw, f.args[1].args[1], f.args[2]) for f in fields]
    local names = [f.args[1].args[1] for f in fields]
    ex.args[3].args = Any[Meta.isexpr(f, :(=)) ? f.args[1] : f for f in ex.args[3].args]
    return esc(quote
        Base.@__doc__ $ex
        $name(; $(keywords...)) = $name($(names...))
    end)
end

"""
$(SIGNATURES)
"""
struct Plain
    a::Float64
    b
end

"""
$(TypedMethodSignatures(false))
"""
struct Typed
    a::Float64
    b
end

"""
$(TypedMethodSignatures(false))
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
$(TypedMethodSignatures(false))
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
