module M

export f

f(x) = x

g(x = 1, y = 2, z = 3; kwargs...) = x

const A{T} = Union{Vector{T}, Matrix{T}}

h_1(x::A) = x
h_2(x::A{Int}) = x
h_3(x::A{T}) where {T} = x

i_1(x; y = x) = x * y
i_2(x::Int; y = x) = x * y
i_3(x::T; y = x) where {T} = x * y
i_4(x; y::T = zero(T), z::U = zero(U)) where {T, U} = x + y + z

j_1(x, y) = x * y # two arguments, no keyword arguments
j_1(x; y = x) = x * y # one argument, one keyword argument

mutable struct T
    a
    b
    c
end

struct K
    K(; a = 1) = new()
end


abstract type AbstractType <: Integer end

struct CustomType{S, T <: Integer} <: Integer
end

primitive type BitType8 8 end

primitive type BitType32 <: Real 32 end

end
