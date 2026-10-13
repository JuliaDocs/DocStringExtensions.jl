"""
The singleton type for [`FUNCTIONNAME`](@ref) abbreviations.
"""
struct FunctionName <: Abbreviation end

"""
An [`Abbreviation`](@ref) that prints the name of the documented function. Use it in a
signature written by hand, for example on a function with no methods yet.

The name is printed as plain text. Indent it or wrap it in backticks to format it as code.

# Examples

```jldoctest
julia> \"""
       `\$(FUNCTIONNAME)(d, θ)` calculates the log density of `d` at `θ`.
       \"""
       function logdensity end;

julia> @doc logdensity
  logdensity(d, θ) calculates the log density of d at θ.
```
"""
const FUNCTIONNAME = FunctionName()

format(::FunctionName, buf, doc) = print(buf, doc_binding(doc).var)
