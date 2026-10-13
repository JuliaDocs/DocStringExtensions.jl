"""
The type for [`FIELDS`](@ref) abbreviations.

$(:FIELDS)
"""
struct TypeFields <: Abbreviation
    types::Bool
    show_defaults::Bool
    defaults::Union{Dict{Symbol,String},Nothing}
end

TypeFields(types::Bool; defaults::Bool = true) = TypeFields(types, defaults, nothing)

interpolation(abbr::TypeFields, expr::Expr) =
    TypeFields(abbr.types, abbr.show_defaults, abbr.show_defaults ? field_defaults(expr) : nothing)

"""
An [`Abbreviation`](@ref) that lists the fields of a type, with the docstring of each field
that has one. A field given a default value, as `Base.@kwdef` allows, shows that default.

# Examples

```jldoctest
julia> \"""
       A point in the plane.
       \$(FIELDS)
       \"""
       Base.@kwdef struct Point
           "Horizontal coordinate."
           x::Float64
           "Vertical coordinate."
           y::Float64
           label::String = "origin"
       end;

julia> @doc Point
  A point in the plane.

    •  x: Horizontal coordinate.

    •  y: Vertical coordinate.

    •  label = "origin"
```

!!! tip "Hiding Default Values"
    To leave out default values, use `\$(DocStringExtensions.TypeFields(false; defaults = false))`.
"""
const FIELDS = TypeFields(false)

"""
An [`Abbreviation`](@ref) that lists the fields of a type like [`FIELDS`](@ref), with the
type of each field.

# Examples

```jldoctest
julia> \"""
       A point in the plane.
       \$(TYPEDFIELDS)
       \"""
       struct Point
           "Horizontal coordinate."
           x::Float64
           "Vertical coordinate."
           y::Float64
           label::String
       end

julia> @doc Point
  A point in the plane.

    •  x::Float64: Horizontal coordinate.

    •  y::Float64: Vertical coordinate.

    •  label::String
```

!!! tip "Hiding Default Values"
    To leave out default values, use `\$(DocStringExtensions.TypeFields(true; defaults = false))`.
"""
const TYPEDFIELDS = TypeFields(true)

function format(abbrv::TypeFields, buf, doc)
    local docs = get(doc.data, :fields, Dict())
    local binding = doc.data[:binding]
    local object = Base.invokelatest(Docs.resolve, binding)
    local fields = isabstracttype(object) ? Symbol[] : fieldnames(object)
    if !isempty(fields)
        println(buf)
        for field in fields
            local text = string(field)
            abbrv.types && (text *= string("::", fieldtype(object, field)))
            local default = abbrv.defaults === nothing ? nothing : get(abbrv.defaults, field, nothing)
            default === nothing || (text *= " = " * first_line(default))
            print(buf, "  - ", code_span(text))
            # Print the field docs if they exist and aren't a `doc"..."` docstring.
            if haskey(docs, field) && isa(docs[field], AbstractString)
                print(buf, ": ")
                indented = true
                for line in split(docs[field], "\n")
                    println(buf, indented || isempty(line) ? "" : "    ", rstrip(line))
                    indented = false
                end
            else
                println(buf)
            end
            println(buf)
        end
        println(buf)
    end
    return nothing
end

# A list item stays on one line, so a multi-line default shows only its first.
first_line(text) = occursin('\n', text) ? string(first(split(text, '\n')), " …") : text

# Julia's Markdown reads an even run of backticks as LaTeX, so the fence is the shortest odd
# run longer than any in `text`. A space keeps a backtick at either end out of the fence.
function code_span(text)
    local longest = reduce(max, [length(m.match) for m in eachmatch(r"`+", text)]; init = 0)
    local fence = "`"^(isodd(longest) ? longest + 2 : longest + 1)
    local padding = startswith(text, '`') || endswith(text, '`') ? " " : ""
    return string(fence, padding, text, padding, fence)
end
