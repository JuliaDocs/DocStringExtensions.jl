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

function format(::ModuleImports, buf, doc)
    local binding = doc.data[:binding]
    local object = Base.invokelatest(Docs.resolve, binding)
    local imports = unique(ccall(:jl_module_usings, Any, (Any,), object))
    return if !isempty(imports)
        println(buf)
        for mod in sort(imports, by = string)
            println(buf, "  - `", mod, "`")
        end
        println(buf)
    end
end
