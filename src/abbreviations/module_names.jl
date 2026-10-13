"""
The singleton type for [`EXPORTS`](@ref) abbreviations.

$(:FIELDS)
"""
struct ModuleExports <: Abbreviation end

"""
An [`Abbreviation`](@ref) that lists the exported names of a module as Documenter.jl
`@ref` links.

# Examples

```jldoctest
julia> \"""
       Shapes and their areas.
       \$(EXPORTS)
       \"""
       module Shapes
       using DocStringExtensions
       export Circle, area
       struct Circle end
       area(::Circle) = π
       end;

julia> @doc Shapes
  Shapes and their areas.

    •  Circle
    •  area
```

!!! note

    The names are sorted alphabetically, ignoring a leading `@`, so macros sort in with the
    other names.
"""
const EXPORTS = ModuleExports()

function format(::ModuleExports, buf, doc)
    local object = Base.invokelatest(Docs.resolve, doc.data[:binding])
    # `names` also returns `public` names on Julia 1.11 and later.
    print_name_list(buf, object, filter(sym -> Base.isexported(object, sym), names(object)))
end

function print_name_list(buf, object::Module, syms)
    if !isempty(syms)
        println(buf)
        # Sorting ignores the `@` in macro names and sorts them in with others.
        for sym in sort(syms, by = s -> lstrip(string(s), '@'))
            # Skip the module itself, since that's always exported.
            sym === nameof(object) && continue
            # We print linked names using Documenter.jl cross-reference syntax
            # for ease of integration with that package.
            println(buf, "  - [`", sym, "`](@ref)")
        end
        println(buf)
    end
    return nothing
end

"""
The singleton type for [`PUBLIC`](@ref) abbreviations.

$(:FIELDS)
"""
struct ModulePublic <: Abbreviation end

"""
An [`Abbreviation`](@ref) that lists the public names of a module, exported or declared
`public`, as Documenter.jl `@ref` links. Before Julia 1.11, which added `public`, it lists
the exported names.

# Examples

```jldoctest
julia> \"""
       Shapes and their areas.
       \$(PUBLIC)
       \"""
       module Shapes
       using DocStringExtensions
       export Circle, area
       public perimeter
       struct Circle end
       area(::Circle) = π
       perimeter(::Circle) = 2π
       end;

julia> @doc Shapes
  Shapes and their areas.

    •  Circle
    •  area
    •  perimeter
```

!!! note

    The names are sorted alphabetically, ignoring a leading `@`, so macros sort in with the
    other names.
"""
const PUBLIC = ModulePublic()

function format(::ModulePublic, buf, doc)
    local object = Base.invokelatest(Docs.resolve, doc.data[:binding])
    print_name_list(buf, object, names(object))
end
