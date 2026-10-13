"""
The singleton type for [`TYPEDEF`](@ref) abbreviations.
"""
struct TypeDefinition <: Abbreviation end

"""
An [`Abbreviation`](@ref) that prints the header of a type definition: `struct`,
`mutable struct`, `abstract type` or `primitive type`, then the unqualified name, the type
parameters, and the supertype unless it is `Any`. A primitive type also shows its size in
bits.

# Examples

```jldoctest
julia> \"""
       \$(TYPEDEF)
       A point in the plane.
       \"""
       struct Point{T<:Real} <: Number
           x::T
           y::T
       end

julia> @doc Point
  struct Point{T<:Real} <: Number

  A point in the plane.
```

!!! note

    The fields are not printed. Use [`FIELDS`](@ref) or [`TYPEDFIELDS`](@ref) for those.
"""
const TYPEDEF = TypeDefinition()

# `io` with the type parameters of `object` in its `:unionall_env`, so that a bound or the
# supertype names them, as in `Leap{T<:Real} <: AbstractLeap{T}` and `{N, T<:Ref{N}}`.
parameter_context(object, io) = unionall_env(filter(p -> p isa TypeVar, collect(object.parameters)), io)

function print_supertype(buf, object, io)
    super = supertype(object)
    return super != Any && print(buf, " <: ", type_text(super, parameter_context(object, io)))
end

function print_params(buf, object, io)
    isempty(object.parameters) && return
    env = parameter_context(object, io)
    print(buf, "{")
    join(buf, map(p -> parameter_text(p, env), object.parameters), ", ")
    print(buf, "}")
    return
end

# A type parameter as `print` writes it, with any parameter written `<:T` inside it as written.
parameter_text(p::TypeVar, io) = typevar_text(p, io)
parameter_text(@nospecialize(p::Type), io) = type_text(p, io)
parameter_text(p, io) = p

function print_primitive_type(buf, object, io)
    print(buf, "primitive type ", object.name.name)
    print_supertype(buf, object, io)
    print(buf, " ", sizeof(object) * 8)
    return println(buf)
end

function print_abstract_type(buf, object, io)
    print(buf, "abstract type ", object.name.name)
    print_params(buf, object, io)
    print_supertype(buf, object, io)
    return println(buf)
end

# This is compat to make sure that we have ismutabletype available pre-1.7.
# Implementation borrowed from JuliaLang/julia (MIT license).
# https://github.com/JuliaLang/julia/pull/39037
if !isdefined(Base, :ismutabletype)
    function ismutabletype(@nospecialize(t::Type))
        t = Base.unwrap_unionall(t)
        return isa(t, DataType) && t.mutable
    end
end

function print_mutable_struct_or_struct(buf, object, io)
    ismutabletype(object) && print(buf, "mutable ")
    print(buf, "struct ", object.name.name)
    print_params(buf, object, io)
    print_supertype(buf, object, io)
    return println(buf)
end

gettype(T::UnionAll) = gettype(T.body)
gettype(other) = other

function format(::TypeDefinition, buf, doc)
    binding = doc_binding(doc)
    object = gettype(Base.invokelatest(Docs.resolve, binding))
    return if isa(object, DataType)
        println(buf, "\n```julia")
        io = alias_context(binding.mod)
        if isprimitivetype(object)
            print_primitive_type(buf, object, io)
        elseif isabstracttype(object)
            print_abstract_type(buf, object, io)
        else
            print_mutable_struct_or_struct(buf, object, io)
        end
        println(buf, "```\n")
    end
end
