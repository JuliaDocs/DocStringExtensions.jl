const expander = Core.atdoc
const setter! = Core.atdoc!

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

# Runs in place of `Core.atdoc`, so it calls the default expander itself.
function template_hook(source::LineNumberNode, mod::Module, docstr, expr::Expr, define...)
    hooked(docstr) || (docstr = hook_docstring(mod, docstr, expr))
    local out = expander(source, mod, docstr, expr, define...)
    return isdefined(mod, TEMP_SYM) ? forward_doc_calls(out) : out
end
# On Julia 1.6 and later, the `@doc` calls that `@__doc__` leaves carry two leading arguments
# that `Docs.docm` drops.
template_hook(source::LineNumberNode, mod::Module, _, _, docstr, expr::Expr, define::Bool) =
    template_hook(source, mod, docstr, expr, define)
template_hook(args...) = expander(args...)

function hook_docstring(mod::Module, docstr, expr::Expr)
    docstr = _capture_expression(docstr, expr)
    # During macro expansion we only need to wrap docstrings in special
    # abbreviations that later print out what was before and after the
    # docstring in it's specific template. This is only done when the module
    # actually defines templates.
    if isdefined(mod, TEMP_SYM)
        dict = getfield(mod, TEMP_SYM)
        # We unwrap interpolated strings so that we can add the `:before` and
        # `:after` abbreviations. Otherwise they're just left as is.
        unwrapped = Meta.isexpr(docstr, :string) ? docstr.args : [docstr]
        before, after = Template{:before}(dict, expr), Template{:after}(dict, expr)
        # Rebuild the original docstring, but with the template abbreviations
        # surrounding it.
        docstr = Expr(:string, before, unwrapped..., after)
    end
    return docstr
end

# `Docs.docm` registers a docstring by calling `Docs.doc!`, which `forward_doc!` replaces.
# Only the expressions leading to such a call are copied, so a large definition is not.
forward_doc_calls(@nospecialize(other)) = other
function forward_doc_calls(ex::Expr)
    local args = ex.args
    for (index, arg) in enumerate(ex.args)
        local forwarded = forward_doc_calls(arg)
        forwarded === arg && continue
        args === ex.args && (args = copy(ex.args))
        args[index] = forwarded
    end
    if Meta.isexpr(ex, :call) && args[1] === Docs.doc!
        args === ex.args && (args = copy(ex.args))
        args[1] = forward_doc!
    end
    return args === ex.args ? ex : Expr(ex.head, args...)
end

# The documented object is defined by now, so the template is resolved and its documented
# expression dropped. A binding that does not exist yet keeps its `Template` parts.
function forward_doc!(mod::Module, binding::Docs.Binding, str::Docs.DocStr, @nospecialize(sig = Union{}))
    isdefined(binding.mod, binding.var) && (str = resolve_templates(str, template_key(binding, sig)))
    return Docs.doc!(mod, binding, str, sig)
end

# A new `DocStr`, since bindings documented together share one and each needs its own template.
function resolve_templates(str::Docs.DocStr, key::Symbol)
    local text = Any[]
    local selector = template_selector(str.text, key)
    for part in str.text
        part isa Template ? append!(text, template_parts(part, selector)) : push!(text, part)
    end
    return Docs.DocStr(Core.svec(text...), str.object, copy(str.data))
end

# `Docs` documents each definition a macro marks with `@__doc__` by passing the docstring this
# hook returned back through `@doc`.
hooked(docstr) = Meta.isexpr(docstr, :string) && any(is_hook_part, docstr.args)
is_hook_part(part) = isa(part, Template) || Meta.isexpr(part, :call) && part.args[1] === interpolation

get_template(t::Dict, k::Symbol) =
    haskey(t, k) ? t[k] :
    k === :ABSTRACTTYPES ? get_template(t, :TYPES) :
    get(t, :DEFAULT, Any[DOCSTRING])

# Every templated package calls these, so compiling them here saves each one doing it.
const PRECOMPILED = (
    (template_hook, (LineNumberNode, Module, String, Expr)),
    (Template{:before}, (Dict{Symbol,Vector}, Expr)),
    (Template{:after}, (Dict{Symbol,Vector}, Expr)),
    (template_parts, (Template{:before}, Symbol)),
    (template_parts, (Template{:after}, Symbol)),
    (forward_doc!, (Module, Docs.Binding, Docs.DocStr, Any)),
)
foreach(((f, types),) -> precompile(f, types), PRECOMPILED)
