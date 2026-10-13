module AliasesTestModule

using DocStringExtensions
# Inferred return types differ between Julia versions.
import DocStringExtensions: TypedMethodSignatures

struct Arr{T, N, B}
    a::B
end

const Mat{T, B} = Arr{T, 2, B}

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
alias `Mat`
"""
Mat(a::AbstractArray) = Arr{eltype(a), 2, typeof(a)}(a)

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
alias `Mat{Int}`
"""
Mat{Int}(a::AbstractArray) = Arr{Int, 2, typeof(a)}(a)

const IMat{B} = Mat{Int, B}

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
alias of an alias `IMat`
"""
IMat(r::Ref) = Arr{Int, 2, typeof(r)}(r)

Arr{T, 2}(a::Tuple) where {T} = Arr{T, 2, typeof(a)}(a)

struct LTA{T, N}
    x::T
end

const LTM = LTA{T, 1} where {T}

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
alias `LTM`
"""
LTM(r::Ref{T}) where {T} = LTA{T, 1}(r[])

struct Curve{D}
    d::D
end

struct Linear end

const LinearCurve = Curve{Linear}

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
constructor `Curve{Linear}`
"""
Curve{Linear}(x::Real) = Curve{Linear}(Linear())

end
