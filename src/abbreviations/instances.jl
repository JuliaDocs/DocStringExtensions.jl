"""
The singleton type for [`INSTANCES`](@ref) abbreviations.
"""
struct EnumInstances <: Abbreviation end

"""
An [`Abbreviation`](@ref) that lists the instances of an enum with their values. It supports
enums defined with `@enum`, and with `@enumx` from EnumX.jl, whose instances it qualifies
with the enum's module name. It prints nothing for other objects.

# Examples

```jldoctest
julia> \"""
       A fruit.
       \$(INSTANCES)
       \"""
       @enum Fruit apple banana = 3 cherry

julia> @doc Fruit
  A fruit.

    •  apple = 0
    •  banana = 3
    •  cherry = 4
```
"""
const INSTANCES = EnumInstances()

function format(::EnumInstances, buf, doc)
    enum = Base.invokelatest(Docs.resolve, doc_binding(doc))
    entries = Base.invokelatest(enum_entries, enum)::Vector{Tuple{String, String}}
    if !isempty(entries)
        println(buf)
        for (name, value) in entries
            println(buf, "  - `", name, "` = ", value)
        end
        println(buf)
    end
    return nothing
end

function enum_entries(enum::Type{<:Base.Enum}, prefix = "")
    entries = Tuple{String, String}[]
    for instance in instances(enum)
        push!(entries, ("$prefix$(Symbol(instance))", string(Integer(instance))))
    end
    return entries
end
# EnumX.jl documents the module that holds its enum type `T`, and callers write `Module.Name`.
enum_entries(mod::Module) = isdefined(mod, :T) ? enum_entries(mod.T, "$(nameof(mod)).") : Tuple{String, String}[]
enum_entries(other, prefix = "") = Tuple{String, String}[]
