struct TypeFields <: Abbreviation
    types::Bool
    show_defaults::Bool
    defaults::Union{Dict{Symbol, String}, Nothing}
end

"""
$(:SIGNATURES)

The abbreviation behind [`FIELDS`](@ref) and [`TYPEDFIELDS`](@ref). `types = true` prints the
type of each field, as `TYPEDFIELDS` does. `defaults = false` leaves out the default values.
"""
TypeFields(; types::Bool = false, defaults::Bool = true) = TypeFields(types, defaults, nothing)

function TypeFields(types::Bool; defaults::Bool = true)
    Base.depwarn("`TypeFields(types; defaults)` is deprecated, use `TypeFields(; types, defaults)` instead.", :TypeFields)
    return TypeFields(; types = types, defaults = defaults)
end

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
    To leave out default values, use `\$(DocStringExtensions.TypeFields(defaults = false))`.
"""
const FIELDS = TypeFields()

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
    To leave out default values, use `\$(DocStringExtensions.TypeFields(types = true, defaults = false))`.
"""
const TYPEDFIELDS = TypeFields(types = true)

function format(abbrv::TypeFields, buf, doc)
    binding = doc_binding(doc)
    object = Base.invokelatest(Docs.resolve, binding)::Union{DataType, UnionAll}
    isabstracttype(object) && return nothing
    fields = fieldnames(object)
    isempty(fields) && return nothing
    docs = get(doc.data, :fields, Dict())
    io = alias_context(binding.mod)
    println(buf)
    for field in fields
        type = abbrv.types ? "::$(type_text(fieldtype(object, field), io))" : ""
        default = abbrv.defaults === nothing ? nothing : get(abbrv.defaults, field, nothing)
        value = default === nothing ? "" : " = $(first_line(default))"
        print(buf, "  - ", code_span("$field$type$value"))
        print_field_doc(buf, get(docs, field, nothing))
        println(buf)
    end
    println(buf)
    return nothing
end

# The rest of a field's list item: its docstring, with each later line indented under the item.
function print_field_doc(buf, text::AbstractString)
    lines = split(text, "\n")
    println(buf, ": ", rstrip(first(lines)))
    for line in lines[2:end]
        println(buf, isempty(line) ? "" : "    ", rstrip(line))
    end
    return nothing
end
# A field with no docstring, or a `doc"..."` one, ends its item bare.
print_field_doc(buf, other) = println(buf)

# A list item stays on one line, so a multi-line default shows only its first.
first_line(text) = occursin('\n', text) ? "$(first(split(text, '\n'))) …" : text

# Julia's Markdown reads an even run of backticks as LaTeX, so the fence is the shortest odd
# run longer than any in `text`. A space keeps a backtick at either end out of the fence.
function code_span(text)
    longest = reduce(max, [length(m.match) for m in eachmatch(r"`+", text)]; init = 0)
    fence = "`"^(isodd(longest) ? longest + 2 : longest + 1)
    padding = startswith(text, '`') || endswith(text, '`') ? " " : ""
    return "$fence$padding$text$padding$fence"
end
