"""
The type for [`BODY`](@ref) abbreviations.

$(:FIELDS)
"""
struct FunctionBody <: Abbreviation
    body::Union{String,Nothing}
end

interpolation(::FunctionBody, expr::Expr) = FunctionBody(definition_body(expr))

"""
An [`Abbreviation`](@ref) that prints the body of the documented method definition as a
Julia code block. Short functions are sometimes best documented by their definition.

It prints nothing when the docstring is not attached to a method definition with a body.

# Examples

```jldoctest
julia> \"""
       Log-odds of the probability `p`:
       \$(BODY)
       \"""
       logit(p) = log(p / (1 - p));

julia> @doc logit
  Log-odds of the probability p:

  log(p / (1 - p))
```
"""
const BODY = FunctionBody(nothing)

function format(abbr::FunctionBody, buf, doc)
    abbr.body === nothing && return
    println(buf)
    println(buf, "```julia")
    println(buf, abbr.body)
    println(buf, "```\n")
end
