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

k_0(x::T) where {T} = x
k_1(x::String, y::T = 0, z::T = zero(T)) where {T <: Number} = x
k_2(x::String, y::U, z::T) where {T <: Number} where {U <: Complex} = x
k_3(x, y::T, z::U) where {T, U} = x + y + z
k_4(::String, ::Int = 0) = nothing
k_5(::Type{T}, x::String, func::Union{Nothing, Function} = nothing) where {T <: Number} = x
k_6(x::Vector{T}) where {T <: Number} = x
k_7(x::Union{T, Nothing}, y::T = zero(T)) where {T <: Integer} = x
k_8(x) = x
k_9(x::T where {T <: Any}) = x
k_11(x::Int, xs...) = x
k_12(x::Int, xs::Real...) = x

function l_1 end
l_1(x::String) = x
l_1(x::Symbol, y::Bool = true) = x
k_13(x = 1, xs...) = x
k_14(x) = x; k_14(x::Int) = x

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

@enum Color red green = 3

# The shape EnumX.jl gives an enum: a module holding the `Enum` subtype `T`.
module Fruit
    @enum T Apple = 1 Banana = 5
end

# The first method's signature lies inside the second's.
overlapping(x::Int8) = x
overlapping(x::Integer) = "x"

@generated overlapping_generated(x::Int8) = :x
overlapping_generated(x::Integer) = "x"

abstract type Shape end
struct Circle <: Shape end
struct Square{T} <: Shape end
abstract type Polygon <: Shape end
struct Triangle <: Polygon end
const Round = Circle
module Solids
    import ..Shape
    struct Sphere <: Shape end
end
const Solid = Solids

abstract type Container{T} end
struct Box{T} <: Container{T} end

k_15(x::T, xs::T...) where {T <: Number} = x
k_16(x::Real, xs::Vararg{Int, 2}) = x
k_17(xs::Vararg{T, 2}) where {T <: Integer} = 1
k_18(x::Int, xs::Vararg{Int, 0}) = x
k_19(x::S) where {T, S <: Ref{T}} = x
k_20(xs::Vararg{T, N}) where {T, N} = 1
k_21(x::T = 1, xs::T...) where {T} = x
k_22(x::T) where {Int8 <: T <: Integer} = x
k_23(_, ::Val{N}, ::String...) where {N} = N

struct Param{T <: Number}
    a::T
end
"Construct a `Param` holding one."
Param{T}() where {T <: Number} = Param{T}(one(T))

struct Param2{T <: Number, S}
    a::T
    b::S
end
Param2{T}(b) where {T <: Number} = Param2{T, typeof(b)}(one(T), b)

i_5(x::T; a::Int = 1, b::T = x, c, d...) where {T <: Real} = x
i_6(xs::Int...; a::Int = 1) = xs

primitive type BitParam{T} <: Real 64 end
struct Tag{A, B} end
const SymbolChar = Tag{:a, 'c'}

k_24(x::T, y::S) where {T, S <: Vector{T}} = 1

struct Pairing{A, F}
    a::A
    f::F
end
k_25(x) = Pairing(x, sin)

end
