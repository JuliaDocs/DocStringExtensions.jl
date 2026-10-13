const expander = Core.atdoc
const setter! = Core.atdoc!

# During macro expansion process the interpolated string and replace all interpolation
# syntax with calls to `interpolation` that pass through the documented expression along
# with the resolved object that was interpolated.
function _capture_expression(docstr::Expr, expr::Expr)
    if Meta.isexpr(docstr, :string)
        quoted = QuoteNode(expr)
        new_docstring = Expr(:string)
        append!(new_docstring.args, [_process_interpolation(each, quoted) for each in docstr.args])
        return new_docstring
    end
    return docstr
end
_capture_expression(@nospecialize(other), ::Expr) = other

_process_interpolation(str::AbstractString, ::QuoteNode) = str
_process_interpolation(@nospecialize(expr), quoted::QuoteNode) = Expr(:call, interpolation, expr, quoted)

# Runs in place of `Core.atdoc`, so it calls the default expander itself.
function template_hook(source::LineNumberNode, mod::Module, docstr, expr::Expr, define...)
    hooked(docstr) || (docstr = hook_docstring(mod, docstr, expr))
    out = expander(source, mod, docstr, expr, define...)
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
    args = ex.args
    for (index, arg) in enumerate(ex.args)
        forwarded = forward_doc_calls(arg)
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
    text = Any[]
    selector = template_selector(str.text, key)
    for part in str.text
        part isa Template ? append!(text, template_parts(part, selector)) : push!(text, part)
    end
    return Docs.DocStr(Core.svec(text...), str.object, copy(str.data))
end

# `Docs` documents each definition a macro marks with `@__doc__` by passing the docstring this
# hook returned back through `@doc`.
hooked(docstr) = Meta.isexpr(docstr, :string) && any(is_hook_part, docstr.args)
is_hook_part(part) = isa(part, Template) || Meta.isexpr(part, :call) && part.args[1] === interpolation

# Every templated package calls these, so compiling them here saves each one doing it.
const PRECOMPILED = (
    (template_hook, (LineNumberNode, Module, String, Expr)),
    (Template{:before}, (Dict{Symbol, Vector}, Expr)),
    (Template{:after}, (Dict{Symbol, Vector}, Expr)),
    (template_parts, (Template{:before}, Symbol)),
    (template_parts, (Template{:after}, Symbol)),
    (forward_doc!, (Module, Docs.Binding, Docs.DocStr, Any)),
)
foreach(((f, types),) -> precompile(f, types), PRECOMPILED)
