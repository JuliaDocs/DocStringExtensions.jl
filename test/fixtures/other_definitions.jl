module OtherDefinitionsTestModule

using DocStringExtensions
# Inferred return types differ between Julia versions.
import DocStringExtensions: TypedMethodSignatures

struct G end

struct D{T, MM}
    g::G
    m::MM
    D{T}(g::G, n::Int, m::MM) where {T, MM} = new{T, MM}(g, m)
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
constructor `D`
"""
function D{T}(g::G, m::MM) where {T, MM}
    return D{T}(g, 1, m)
end

(::Type{<:D})(n::Integer) = D{true}(G(), 0, n)

struct E{NF}
    r::NF
end

E(::Type{NF}; kwargs...) where {NF} = E{NF}(zero(NF))

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
callable `E`
"""
(e::E)(σ) = e.r

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
macro `@mac`
"""
macro mac(xs...)
    return nothing
end

end
