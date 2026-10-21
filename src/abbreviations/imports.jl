"""
The singleton type for [`IMPORTS`](@ref) abbreviations.
"""
struct ModuleImports <: Abbreviation end

"""
An [`Abbreviation`](@ref) that lists, sorted by name, the modules a module loads with
`using`. The list includes `Base`, which every module uses implicitly.

# Examples

```jldoctest
julia> \"""
       Plotting helpers.
       \$(IMPORTS)
       \"""
       module Plots
       using DocStringExtensions, Markdown
       end;

julia> @doc Plots
  Plotting helpers.

    •  Base
    •  DocStringExtensions
    •  Markdown
```
"""
const IMPORTS = ModuleImports()

# Kept out of `format`: Julia compiles any method holding a `ccall`, even in an interpreted module.
module_usings(mod::Module) = ccall(:jl_module_usings, Any, (Any,), mod)::Vector{Any}

function format(::ModuleImports, buf, doc)
    binding = doc_binding(doc)
    object = Base.invokelatest(Docs.resolve, binding)::Module
    imports = Module[]
    for mod in module_usings(object)
        mod in imports || push!(imports, mod)
    end
    return if !isempty(imports)
        println(buf)
        for mod in insertion_sort!(imports, (a, b) -> string(a) < string(b))
            println(buf, "  - `", mod, "`")
        end
        println(buf)
    end
end
