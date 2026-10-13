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
    entries = Base.invokelatest(enum_entries ∘ Docs.resolve, doc.data[:binding])
    if !isempty(entries)
        println(buf)
        for (name, value) in entries
            println(buf, "  - `", name, "` = ", value)
        end
        println(buf)
    end
    return nothing
end

enum_entries(enum::Type{<:Base.Enum}, prefix = "") =
    [(string(prefix, Symbol(instance)), Integer(instance)) for instance in instances(enum)]
# EnumX.jl documents the module that holds its enum type `T`, and callers write `Module.Name`.
enum_entries(mod::Module) = isdefined(mod, :T) ? enum_entries(mod.T, string(nameof(mod), ".")) : []
enum_entries(other, prefix = "") = []
