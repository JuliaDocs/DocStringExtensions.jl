"""
$(:SIGNATURES)

Defines a docstring template for a category, or a tuple of categories, of documented
bindings in the current module.

Each matching docstring that follows the `@template` is replaced by the template, with the
original docstring placed where the template's [`DOCSTRING`](@ref) abbreviation is. Every
template must contain `DOCSTRING`. Docstrings defined before the `@template` are left as
they are, so define templates before the definitions they should apply to. A template applies
only in the module that defines it. Submodules need their own, or a copy as shown below. A
docstring that contains [`NOTEMPLATE`](@ref) renders as written.

# Examples

```jldoctest
julia> module Geometry
       using DocStringExtensions
       @template (FUNCTIONS, METHODS) = \"""
           \$(TYPEDSIGNATURES)
           \$(DOCSTRING)
           \"""
       "Compute the area of a square."
       area(side::Int) = side^2
       end;

julia> @doc Geometry.area
  area(side::Int64) -> Int64

  Compute the area of a square.
```

The remaining examples show the other forms of `@template`.

```julia
@template DEFAULT =
    \"""
    \$(SIGNATURES)
    \$(DOCSTRING)
    \"""
```

`DEFAULT` applies to a docstring when no template for its own category, or for the category
it falls back to, exists.

```julia
@template ABSTRACTTYPES =
    \"""
    \$(TYPEDEF)
    \$(DOCSTRING)
    \$(SUBTYPES)
    \"""
```

`ABSTRACTTYPES` applies to abstract types, and `TYPES` to every other type. A module without an
`ABSTRACTTYPES` template documents abstract types with its `TYPES` template.

```julia
@template (FUNCTIONS, METHODS, MACROS) =
    \"""
    \$(SIGNATURES)
    \$(DOCSTRING)
    \$(METHODLIST)
    \"""
```

A tuple of categories gives several categories the same template.

```julia
@template MODULES = ModName
```

A module name on the right copies that module's template for the same category. `ModName`
must already define a `MODULES` template, so a module cannot copy a template from itself.
To share templates across a package, define them in the parent module and copy them into
each submodule:

```julia
module Parent
using DocStringExtensions
@template MODULES = \"""
    \$(DOCSTRING)
    \$(EXPORTS)
    \"""

module Child
using DocStringExtensions
@template MODULES = Parent
end
end
```

!!! note

    Supported categories are `DEFAULT`, `FUNCTIONS`, `METHODS`, `MACROS`, `TYPES`,
    `ABSTRACTTYPES`, `MODULES`, and `CONSTANTS`.
"""
macro template(ex)
    template(__source__, __module__, ex)
end

const TEMP_SYM = gensym("templates")

function template(src::LineNumberNode, mod::Module, ex::Expr)
    Meta.isexpr(ex, :(=), 2) || error("invalid `@template` syntax.")
    template(src, mod, ex.args[1], ex.args[2])
end

function template(source::LineNumberNode, mod::Module, tuple::Expr, docstr::Union{String, Symbol, Expr})
    Meta.isexpr(tuple, :tuple) || error("invalid `@template` syntax on LHS.")
    isdefined(mod, TEMP_SYM) || Core.eval(mod, :(const $(TEMP_SYM) = $(Dict{Symbol, Vector}())))
    local block = Expr(:block)
    for category in tuple.args
        local key = Meta.quot(category)
        local vec =
            docstr isa String ? :($(checked_template)([$(docstr)])) :
            Meta.isexpr(docstr, :string) ? :($(checked_template)($(Expr(:vect, docstr.args...)))) :
            :($(copied_template)($(docstr), $(key)))
        push!(block.args, :($(TEMP_SYM)[$(checked_category)($(key))] = $(vec)))
    end
    push!(block.args, nothing)
    return esc(block)
end

function template(src::LineNumberNode, mod::Module, sym::Symbol, docstr::Union{String, Symbol, Expr})
    template(src, mod, Expr(:tuple, sym), docstr)
end

const TEMPLATE_CATEGORIES = (:DEFAULT, :FUNCTIONS, :METHODS, :MACROS, :TYPES, :ABSTRACTTYPES, :MODULES, :CONSTANTS)

function checked_category(category)
    category in TEMPLATE_CATEGORIES || throw(ArgumentError(
        "`@template` category `$category` is not one of $(join(TEMPLATE_CATEGORIES, ", "))."
    ))
    return category
end

function checked_template(parts::Vector)
    any(is_docstr_template, parts) ||
        throw(ArgumentError("`@template` string has no `\$(DOCSTRING)` to mark where the docstring goes."))
    return parts
end

function copied_template(source::Module, category::Symbol)
    isdefined(source, TEMP_SYM) && haskey(getfield(source, TEMP_SYM), category) &&
        return getfield(source, TEMP_SYM)[category]
    local name = nameof(source)
    throw(ArgumentError(
        "module `$name` has no `$category` template to copy. " *
        "Define one with `@template $category = \"...\"` in `$name` before copying it."
    ))
end

get_template(t::Dict, k::Symbol) =
    haskey(t, k) ? t[k] :
    k === :ABSTRACTTYPES ? get_template(t, :TYPES) :
    get(t, :DEFAULT, Any[DOCSTRING])

# The docstring's `TemplateOverride` if it has one, otherwise the `inferred` category.
function template_selector(text, inferred::Symbol)
    for part in text
        part isa TemplateOverride && return part
    end
    return inferred
end

"""
Internal abbreviation type used to wrap templated docstrings.

`Location` is a `Symbol`, either `:before` or `:after`. `dict` stores a
reference to a module's templates. `expr` is the documented expression, which is
passed to [`interpolation`](@ref) for each part of the template.
"""
struct Template{Location} <: Abbreviation
    dict::Dict{Symbol,Vector{Any}}
    expr::Expr
end

function format(abbr::Template, buf, doc)
    for part in template_parts(abbr, template_selector(doc.text, template_key(doc)))
        # We don't call `DocStringExtensions.format` here since we need to be
        # able to format any content in docstrings, rather than just
        # abbreviations.
        Docs.formatdoc(buf, doc, part)
    end
end

# The parts of the template for `key` found before the `DOCSTRING` abbreviation, or after it.
function template_parts(abbr::Template, key::Symbol)
    local parts = get_template(abbr.dict, key)
    return Any[interpolation(parts[index], abbr.expr) for index in included_range(abbr, parts)]
end
function template_parts(abbr::Template, override::TemplateOverride)
    local category = override.category
    category === nothing && return Any[]
    haskey(abbr.dict, category) || throw(ArgumentError(
        "`TemplateOverride` category `$category` has no template. " *
        "Define one with `@template $category = \"...\"` before the docstring."
    ))
    return template_parts(abbr, category)
end

function included_range(abbr::Template, parts::Vector)
    # Select the correct indexing depending on what we find.
    build_range(::Template{:before}, index) = 1:(index - 1)
    build_range(::Template{:after}, index) = (index + 1):lastindex(parts)
    # Search for index from either the front or back.
    find_index(::Template{:before}) = findfirst(is_docstr_template, parts)
    find_index(::Template{:after}) = findlast(is_docstr_template, parts)
    # Find and return the correct indices.
    return build_range(abbr, find_index(abbr))
end

# Runs as each templated docstring is registered. Specialising on the documented object would
# compile, and cache in the documenting package's image, an instance for every function.
function template_key(binding::Docs.Binding, @nospecialize(typesig))
    # Local helper methods for extracting the template key from a docstring.
    ismacro(b::Docs.Binding) = startswith(string(b.var), '@')
    objname(@nospecialize(obj::Union{Function,Module,DataType,Core.IntrinsicFunction}), b::Docs.Binding) = nameof(obj)
    objname(@nospecialize(obj::UnionAll), b::Docs.Binding) = objname(Base.unwrap_unionall(obj), b)
    objname(@nospecialize(obj), b::Docs.Binding) = Symbol("") # Empty to force resolving to `:CONSTANTS` below.
    # Select the key returned based on input argument types.
    _key(@nospecialize(::Module), @nospecialize(sig), binding)   = :MODULES
    _key(@nospecialize(::Function), ::typeof(Union{}), binding)  = ismacro(binding) ? :MACROS : :FUNCTIONS
    _key(@nospecialize(::Function), @nospecialize(sig), binding) = ismacro(binding) ? :MACROS : :METHODS
    _key(@nospecialize(T::Union{DataType,UnionAll}), ::typeof(Union{}), binding) =
        Base.isabstracttype(T) ? :ABSTRACTTYPES : :TYPES
    _key(@nospecialize(_::Union{DataType,UnionAll}), @nospecialize(sig), binding) = :METHODS
    _key(@nospecialize(other), @nospecialize(sig), binding)      = :DEFAULT

    obj = Base.invokelatest(Docs.resolve, binding)
    name = objname(obj, binding)
    key = name === binding.var ? _key(obj, typesig, binding) : :CONSTANTS
    return key
end
template_key(doc::Docs.DocStr) = template_key(doc.data[:binding], doc.data[:typesig])
