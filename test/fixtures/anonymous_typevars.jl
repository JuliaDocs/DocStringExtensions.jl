module AnonymousTypeVarsTestModule

using DocStringExtensions
# Inferred return types differ between Julia versions.
import DocStringExtensions: TypedMethodSignatures

struct Grid end

abstract type Container{T} end

# Applying an alias to `<:T` leaves Julia's generated type variable in more than one place, or
# deeper than the parameter written `<:T`, so these print as the alias. Before Julia 1.6
# `AbstractVector` prints as `AbstractArray{T,1}`, so the rendered fixtures use `ScalarOrRef`.
const ScalarOrVec{T} = Union{T, AbstractVector{T}} where {T <: Real}
const ScalarOrRef{T} = Union{T, Ref{T}} where {T <: Real}
const RefRef{T} = Ref{Ref{T}}
struct SmallVec{T, V} end
"""
$(TYPEDEF)
alias `SmallV`
"""
const SmallV{T} = SmallVec{T, Vector{T}}
const Keyed{K, T} = Pair{K, Union{T, Ref{T}}}
# An alias whose body declares its own type variable, one around a `Vararg`, and one around
# `Type{T}`, a `TypeEq` from Julia 1.14.
const RefsOf{T} = Vector{Ref{S} where {S <: T}}
const TupleOf{T} = Tuple{Vararg{T}}
const Rows{T, N} = Tuple{Vararg{T, N}}
const Kinds{T} = Pair{Type{T}, T}
# Same shapes as `RefRef` and `Keyed`, with bounds that rule them out. They sort first by name.
const IntRef{T <: Integer} = Ref{Ref{T}}
const IdPair{K <: AbstractString, T} = Pair{K, Union{T, Ref{T}}}

"""
$(TYPEDFIELDS)
type `Fields`
"""
struct Fields
    real::Ref{<:Real}
    grid::Type{<:Grid}
    above::Union{Nothing, Ref{>:Integer}}
    nested::Ref{Ref{<:Real}}
    any::Ref{<:Any}
    shared::ScalarOrRef{<:AbstractFloat}
    deep::RefRef{<:Real}
    small::SmallV{<:Union{Int8, String}}
    keyed::Keyed{Symbol, <:Real}
    boxed::Ref{ScalarOrRef{<:AbstractFloat}}
    kind::Type{ScalarOrRef{<:AbstractFloat}}
    named::Union{T, Ref{T}} where {T <: Real}
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
type `Bounded`
"""
struct Bounded{T <: Ref{<:Real}} <: Container{Ref{<:Real}}
    x::T
end

abstract type Tagged{T, N} end

"""
$(TYPEDEF)
instance `Instance`
"""
const Instance = Tagged{Ref{<:Real}, 1}

abstract type AbstractLeap{T} end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
type `Leap`
"""
struct Leap{T <: ScalarOrRef{<:AbstractFloat}} <: AbstractLeap{T}
    step::T
end

# Bounds that refer to an earlier parameter, which prints by name.
"""
$(TYPEDEF)
type `Extended`
"""
struct Extended{T3 <: Number, T <: Ref{T3}} end

"""
$(TYPEDEF)
type `Jittered`
"""
struct Jittered{FT <: AbstractFloat, T <: ScalarOrRef{FT}} end

abstract type Shaped{A, B, C, D, E, F} end

"""
$(TYPEDEF)
type `Shapes`
"""
struct Shapes{
        A <: SmallV{<:Union{Int8, String}},
        B <: RefRef{<:Real},
        C <: Keyed{Symbol, <:Real},
        D <: Ref{ScalarOrRef{<:AbstractFloat}},
        E <: Type{ScalarOrRef{<:AbstractFloat}},
    } <: Shaped{
        ScalarOrRef{<:AbstractFloat},
        SmallV{<:Union{Int8, String}},
        RefRef{<:Real},
        Keyed{Symbol, <:Real},
        Ref{ScalarOrRef{<:AbstractFloat}},
        Type{ScalarOrRef{<:AbstractFloat}},
    }
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
method `grids`
"""
grids(xs::Type{<:Grid}...) = xs

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
method `unnamed`
"""
unnamed(::Type{<:Grid}...) = 0

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
method `anys`
"""
anys(x::Ref{<:Any}, ::Ref{<:Any}) = x

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
method `bounded`
"""
bounded(x::T) where {T <: Ref{<:Real}} = x

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
method `scaled`
"""
scaled(x::ScalarOrRef{<:AbstractFloat}, y::T) where {T} = y

# Each returns its argument, so its inferred return type is the argument's type.
"""
$(TYPEDSIGNATURES)
method `scalar`
"""
scalar(x::ScalarOrRef{<:AbstractFloat}) = x

"""
$(TYPEDSIGNATURES)
method `small`
"""
small(x::SmallV{<:Union{Int8, String}}) = x

"""
$(TYPEDSIGNATURES)
method `deep`
"""
deep(x::RefRef{<:Real}) = x

"""
$(TYPEDSIGNATURES)
method `keyed`
"""
keyed(x::Keyed{Symbol, <:Real}) = x

"""
$(TYPEDSIGNATURES)
method `boxed`
"""
boxed(x::Ref{ScalarOrRef{<:AbstractFloat}}) = x

"""
$(TYPEDSIGNATURES)
method `kind`
"""
kind(x::Type{ScalarOrRef{<:AbstractFloat}}) = x

# A type no alias gives: its generated variable can't be written, so the inferred return type
# is left out.
struct Holder
    x::(Union{T, Tuple{T}} where {T}){<:Real}
end

"""
$(TYPEDSIGNATURES)
method `held`
"""
held(h::Holder) = h.x

module Lib
    const PairOf{T} = Pair{T, Ref{T}}
end

# An alias of a parent module, and one the module imports.
module Nested
    using DocStringExtensions
    import ..AnonymousTypeVarsTestModule
    import ..Lib: PairOf

    """
    $(TYPEDEF)
    $(TYPEDFIELDS)
    type `Leaf`
    """
    struct Leaf{T <: AnonymousTypeVarsTestModule.ScalarOrRef{<:AbstractFloat}}
        step::T
        pair::PairOf{<:Real}
    end

    """
    $(TYPEDSIGNATURES)
    method `leaf`
    """
    leaf(x::AnonymousTypeVarsTestModule.ScalarOrRef{<:AbstractFloat}) = x
end

# Two aliases of the same type: the first by name prints.
module TwoAliases
    const Crate{T} = Ref{Ref{T}}
    const Box{T} = Ref{Ref{T}}
end

end
