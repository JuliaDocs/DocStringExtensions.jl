module CallablesTestModule

using DocStringExtensions
# Inferred return types differ between Julia versions.
import DocStringExtensions: TypedMethodSignatures

struct Scale
    factor
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
callable `Scale`
"""
(s::Scale)(x::Real) = s.factor * x

struct Zero end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
callable `Zero`
"""
(::Zero)(σ) = 0

# The constructors `Base.@kwdef` writes for `rate::NF = 0.2`, which Julia 1.0 rejects.
struct Entrainment{NF}
    rate::NF
end

Entrainment(; rate = 0.2) = Entrainment(rate)
Entrainment{NF}(; rate = 0.2) where {NF} = Entrainment{NF}(rate)
Entrainment(::Type{NF}; kwargs...) where {NF} = Entrainment{NF}(; kwargs...)

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
callable `Entrainment`
"""
(e::Entrainment)(σ) = e.rate * σ

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
callable `Entrainment{NF}`
"""
(e::Entrainment{NF})(σ, τ::NF) where {NF} = e.rate * σ * τ

struct Reconstruct
    src
    dst
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
callable `Reconstruct`
"""
(rip::Reconstruct)(srcvalp, dstvalp) = (rip.src, rip.dst)

struct Weighted end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
callable `Weighted`
"""
(w::Weighted)(x; weight::Int = 1) = weight * x

struct Grid{T}
    n::T
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
callable `Type{<:Grid}`
"""
(::Type{<:Grid})(n::Integer) = Grid{Int}(n)

struct Arr{T, N}
    x::T
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
callable `Type{T}`
"""
(::Type{T})(x::Symbol) where {T <: Arr} = T(1)

struct Wrap{T} end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
callable `Type{V}` with a bound that names `T`
"""
(::Type{V})(x::Symbol) where {T, V <: Wrap{Vector{T}}} = V()

struct Counter
    n::Int8
end

"""
$(TYPEDSIGNATURES)
callable `Counter` with its return type
"""
(c::Counter)(x::Int8) = x

struct Boxed{T}
    x::T
end

"""
$(TYPEDSIGNATURES)
constructor `Boxed{T}` with its return type
"""
Boxed{T}(x::Int8, y::Int8) where {T} = Boxed{T}(T(x + y))

struct Listed{NF}
    r::NF
end

"""
$(METHODLIST)
callable `Listed`
"""
(l::Listed)(x, y) = x

"""
$(METHODLIST)
constructor `Listed`
"""
Listed(x::Int, y::Int) = Listed{Int}(x)

end
