"""
A method for [`$(FUNCTIONNAME)`](@ref) with one type parameter. [`TYPEDSIGNATURES`](@ref):

$(TYPEDSIGNATURES)

For comparison, [`SIGNATURES`](@ref):

$(SIGNATURES)
"""
bar(x::AbstractArray{T}, y::T) where {T <: Integer} = Int(y)

"""
A method for [`$(FUNCTIONNAME)`](@ref) with an unnamed argument. [`TYPEDSIGNATURES`](@ref):

$(TYPEDSIGNATURES)

For comparison, [`SIGNATURES`](@ref):

$(SIGNATURES)
"""
bar(x::AbstractArray{T}, ::String) where {T <: Integer} = x

"""
A method for [`$(FUNCTIONNAME)`](@ref) with two type parameters. [`TYPEDSIGNATURES`](@ref):

$(TYPEDSIGNATURES)

For comparison, [`SIGNATURES`](@ref):

$(SIGNATURES)
"""
bar(x::AbstractArray{T}, y::U) where {T <: Integer, U <: AbstractFloat} = 0
