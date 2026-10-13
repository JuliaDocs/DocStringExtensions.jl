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

function print_supertype(buf, object)
    super = supertype(object)
    return super != Any && print(buf, " <: ", super)
end

function print_params(buf, object)
    return if !isempty(object.parameters)
        print(buf, "{")
        join(buf, object.parameters, ", ")
        print(buf, "}")
    end
end

function print_primitive_type(buf, object)
    print(buf, "primitive type ", object.name.name)
    print_supertype(buf, object)
    print(buf, " ", sizeof(object) * 8)
    return println(buf)
end

function print_abstract_type(buf, object)
    print(buf, "abstract type ", object.name.name)
    print_params(buf, object)
    print_supertype(buf, object)
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

function print_mutable_struct_or_struct(buf, object)
    ismutabletype(object) && print(buf, "mutable ")
    print(buf, "struct ", object.name.name)
    print_params(buf, object)
    print_supertype(buf, object)
    return println(buf)
end

gettype(T::UnionAll) = gettype(T.body)
gettype(other) = other

function format(::TypeDefinition, buf, doc)
    binding = doc_binding(doc)
    object = gettype(Base.invokelatest(Docs.resolve, binding))
    return if isa(object, DataType)
        println(buf, "\n```julia")
        if isprimitivetype(object)
            print_primitive_type(buf, object)
        elseif isabstracttype(object)
            print_abstract_type(buf, object)
        else
            print_mutable_struct_or_struct(buf, object)
        end
        println(buf, "```\n")
    end
end
