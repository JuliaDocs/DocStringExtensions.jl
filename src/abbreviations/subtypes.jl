"""
The singleton type for [`SUBTYPES`](@ref) abbreviations.
"""
struct TypeSubtypes <: Abbreviation end

"""
An [`Abbreviation`](@ref) that lists the direct subtypes of a type as Documenter.jl `@ref`
links. It prints nothing for other objects.

# Examples

```jldoctest
julia> \"""
       A shape.
       \$(SUBTYPES)
       \"""
       abstract type Shape end

julia> struct Circle <: Shape end

julia> struct Square <: Shape end

julia> @doc Shape
  A shape.

    •  Circle
    •  Square
```

!!! note

    Only subtypes defined in the type's own module, or in a module inside it, are listed,
    so a subtype another package defines is left out. A subtype in an inner module is
    qualified with that module's name.
"""
const SUBTYPES = TypeSubtypes()

function format(::TypeSubtypes, buf, doc)
    local names = Base.invokelatest(subtype_names ∘ Docs.resolve, doc.data[:binding])
    if !isempty(names)
        println(buf)
        for name in names
            println(buf, "  - [`", name, "`](@ref)")
        end
        println(buf)
    end
    return nothing
end

function subtype_names(T::Type)
    local body = Base.unwrap_unionall(T)
    body isa DataType || return String[]
    return sort!(subtype_names!(String[], body.name, parentmodule(body), ""))
end
subtype_names(other) = String[]

function subtype_names!(found, typename, mod::Module, prefix)
    for sym in names(mod; all = true)
        isdefined(mod, sym) || continue
        local obj = getfield(mod, sym)
        if obj isa Module
            obj !== mod && parentmodule(obj) === mod &&
                subtype_names!(found, typename, obj, string(prefix, sym, "."))
        elseif obj isa Type
            local body = Base.unwrap_unionall(obj)
            # Skipping aliases and types defined elsewhere lists each subtype once, by its own name.
            body isa DataType && nameof(body) === sym && parentmodule(body) === mod &&
                Base.unwrap_unionall(supertype(body)).name === typename &&
                push!(found, string(prefix, sym))
        end
    end
    return found
end
