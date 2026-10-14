module PartialParametersTestModule

using DocStringExtensions
# Inferred return types differ between Julia versions.
import DocStringExtensions: TypedMethodSignatures

struct G end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
type `D`
"""
struct D{T, MM}
    g::G
    m::MM
    D{T}(g::G, n::Integer, m::MM) where {T, MM} = new{T, MM}(g, m)
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
constructor `D{T}(g)`
"""
function D{T}(g::G) where {T}
    return D{T}(g, 0, 1)
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
constructor `D{T}(g, m)`
"""
function D{T}(g::G, m::MM) where {T, MM}
    return D{T}(g, 1, m)
end

(::Type{<:D})(n::Integer) = D{true}(G(), 0, n)

struct F{Fold, S}
    subber::S
    maxiters::Int
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
constructor `F(subber)`
"""
F(subber::S; maxiters = 1000) where {S} = F{false}(subber; maxiters = maxiters)

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
constructor `F{Fold}(subber)`
"""
F{Fold}(subber::S; maxiters = 1000) where {Fold, S} = F{Fold, S}(subber, maxiters)

end
