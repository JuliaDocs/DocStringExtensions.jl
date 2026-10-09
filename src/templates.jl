const expander = Core.atdoc
const setter! = Core.atdoc!

"""
$(:SIGNATURES)

Set the docstring expander function to first call `func` before calling the default expander.

To remove a hook that has been applied using this method call [`hook!()`](@ref).
"""
hook!(func) = setter!((args...) -> expander(func(args...)...))

"""
$(:SIGNATURES)

Reset the docstring expander to only call the default expander function. This clears any
'hook' that has been set using [`hook!(func)`](@ref).
"""
hook!() = setter!(expander)

"""
$(:SIGNATURES)

Defines a docstring template that will be applied to all docstrings in a module that match
the specified category or tuple of categories of documented bindings.

Effectively, it replaces each matching docstring that follows it in the module with the
template. Docstrings defined before the `@template` are left as they are.
Every template string must contain the `DOCSTRING` abbreviation, which marks where the
original docstring is spliced into the replacement docstring generated from the template.

# Examples

```julia
@template DEFAULT =
    \"""
    \$(SIGNATURES)
    \$(DOCSTRING)
    \"""
```

`DEFAULT` is the default template that is applied to a docstring if no other template
definitions match the documented expression. The `DOCSTRING` abbreviation is used to mark
the location in the template where the actual docstring body will be spliced into each
docstring.

```julia
@template (FUNCTIONS, METHODS, MACROS) =
    \"""
    \$(SIGNATURES)
    \$(DOCSTRING)
    \$(METHODLIST)
    \"""
```

A tuple of categories can be specified when a docstring template should be used for several
different categories.

```julia
@template MODULES = ModName
```

The template definition above will define a template for module docstrings based on the
template for modules found in module `ModName`.

!!! note

    Supported categories are `DEFAULT`, `FUNCTIONS`, `METHODS`, `MACROS`, `TYPES`,
    `MODULES`, and `CONSTANTS`.

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
            :($(docstr).$(TEMP_SYM)[$(key)])
        push!(block.args, :($(TEMP_SYM)[$(key)] = $(vec)))
    end
    push!(block.args, nothing)
    return esc(block)
end

function template(src::LineNumberNode, mod::Module, sym::Symbol, docstr::Union{String, Symbol, Expr})
    template(src, mod, Expr(:tuple, sym), docstr)
end

function checked_template(parts::Vector)
    any(is_docstr_template, parts) ||
        throw(ArgumentError("`@template` string has no `\$(DOCSTRING)` to mark where the docstring goes."))
    return parts
end

# A template is chosen by the binding that `doc!` records, and its parts are interpolated
# with `expr`. `resolve_templates!` runs after `doc!`, so `expr` is held only by code that is
# discarded once it runs, never by the docstring.
function template_hook(source::LineNumberNode, mod::Module, docstr, expr::Expr)
    docstr = _capture_expression(docstr, expr)
    isdefined(mod, TEMP_SYM) || return expander(source, mod, docstr, expr)
    local before, after, recorded = Template(), Template(), Ref{Docs.DocStr}()
    # Mirrors how `Docs` turns a docstring into the lazily formatted text of a `DocStr`.
    local body = Meta.isexpr(docstr, :string) ? docstr.args : [docstr]
    docstr = Expr(:call, record!, recorded, Expr(:call, Core.svec, before, body..., after))
    local out = expander(source, mod, docstr, expr)
    local dict = getfield(mod, TEMP_SYM)
    return Expr(:call, resolve_templates!, dict, recorded, before, after, QuoteNode(expr), out)
end
template_hook(args...) = expander(args...)

# `Docs` stores a `DocStr` given as the docstring as that same object.
record!(recorded::Ref{Docs.DocStr}, text::Core.SimpleVector) = recorded[] = Docs.docstr(text)

function resolve_templates!(dict, recorded::Ref{Docs.DocStr}, before::Template, after::Template, expr::Expr, value)
    local data = recorded[].data
    local parts = get_template(dict, template_key(data[:binding], data[:typesig]))
    before.parts = interpolate(parts[1:(findfirst(is_docstr_template, parts) - 1)], expr)
    after.parts = interpolate(parts[(findlast(is_docstr_template, parts) + 1):end], expr)
    return value
end

interpolate(parts, expr::Expr) = Any[interpolation(part, expr) for part in parts]

get_template(t::Dict, k::Symbol) = haskey(t, k) ? t[k] : get(t, :DEFAULT, Any[DOCSTRING])
