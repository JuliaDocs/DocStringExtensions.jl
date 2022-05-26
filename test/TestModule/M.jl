module M

export f

f(x) = x

g(x = 1, y = 2, z = 3; kwargs...) = x

h(x::Int, y::Int = 2, z::Int = 3; kwargs...) = x

const A{T} = Union{Array{T, 3}, Array{T, 4}}

h_1(x::A) = x
h_2(x::A{Int}) = x
h_3(x::A{T}) where {T} = x
h_4(x, ::Int, z) = x

@generated g_1(x) = x
@generated g_2(x::String) = x

i_1(x; y = x) = x * y
i_2(x::Int; y = x) = x * y
i_3(x::T; y = x) where {T} = x * y
i_4(x; y::T = zero(T), z::U = zero(U)) where {T, U} = x + y + z

j_1(x, y) = x * y # two arguments, no keyword arguments
j_1(x; y = x) = x * y # one argument, one keyword argument

k_0(x::T) where T = x
k_1(x::String, y::T = 0, z::T = zero(T)) where T <: Number = x
k_2(x::String, y::U, z::T) where T <: Number where U <: Complex = x
k_3(x, y::T, z::U) where {T, U} = x + y + z
k_4(::String, ::Int = 0) = nothing
k_5(::Type{T}, x::String, func::Union{Nothing, Function} = nothing) where T <: Number = x
k_6(x::Vector{T}) where T <: Number = x
k_7(x::Union{T,Nothing}, y::T = zero(T)) where {T <: Integer} = x
k_8(x) = x
k_9(x::T where T<:Any) = x
k_11(x::Int, xs...) = x
k_12(x::Int, xs::Real...) = x

mutable struct T
    a
    b
    c
end

struct K
    K(; a = 1) = new()
end

abstract type AbstractType1 <: Integer end
abstract type AbstractType2{S, T <: Integer} <: Integer end

struct CustomType{S, T <: Integer} <: Integer
end

primitive type BitType8 8 end

primitive type BitType32 <: Real 32 end

end
