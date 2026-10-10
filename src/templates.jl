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
        # Templates outlive macro expansion, so keep `expr` only when a part uses it.
        captured = uses_expression(dict) ? expr : nothing
        before, after = Template{:before}(dict, captured), Template{:after}(dict, captured)
        # Rebuild the original docstring, but with the template abbreviations
        # surrounding it.
        docstr = Expr(:string, before, unwrapped..., after)
    end
    return docstr
end

# `Docs.docm` registers a docstring by calling `Docs.doc!`, which `forward_doc!` replaces.
forward_doc_calls(@nospecialize(other)) = other
forward_doc_calls(quoted::QuoteNode) = QuoteNode(forward_doc_calls(quoted.value))
function forward_doc_calls(ex::Expr)
    local args = Any[forward_doc_calls(arg) for arg in ex.args]
    Meta.isexpr(ex, :call) && args[1] === Docs.doc! && (args[1] = forward_doc!)
    return Expr(ex.head, args...)
end

# The documented object is defined by now, so the template is resolved and its documented
# expression dropped. A signature documented before its method keeps its `Template` parts.
function forward_doc!(mod::Module, binding::Docs.Binding, str::Docs.DocStr, sig = Union{})
    isdefined(binding.mod, binding.var) && resolve_templates!(str, template_key(binding, sig))
    return Docs.doc!(mod, binding, str, sig)
end

function resolve_templates!(str::Docs.DocStr, key::Symbol)
    local text = Any[]
    for part in str.text
        part isa Template ? append!(text, template_parts(part, key)) : push!(text, part)
    end
    str.text = Core.svec(text...)
    return str
end

# Before Julia 1.6, `Docs` documents each definition a macro marks with `@__doc__` by passing
# the docstring this hook returned back through `@doc`.
hooked(docstr) = Meta.isexpr(docstr, :string) && any(is_hook_part, docstr.args)
is_hook_part(part) = isa(part, Template) || Meta.isexpr(part, :call) && part.args[1] === interpolation

uses_expression(dict) = any(parts -> any(needs_expression, parts), values(dict))

# Whether `interpolation` may use the documented expression for a template `part`. This
# runs during macro expansion for every category, so it must not call `interpolation`.
needs_expression(::AbstractString) = false
function needs_expression(part)
    parentmodule(typeof(part)) === DocStringExtensions && return false
    local method = Base.invokelatest(which, interpolation, Tuple{typeof(part),Expr})
    return method.sig !== Tuple{typeof(interpolation),Any,Any}
end

get_template(t::Dict, k::Symbol) = haskey(t, k) ? t[k] : get(t, :DEFAULT, Any[DOCSTRING])
