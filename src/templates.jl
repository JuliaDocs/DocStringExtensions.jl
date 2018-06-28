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
the specified category or tuple of categories.

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
    # JuliaLang/julia#22064 introduced the __module__ variable and deprecated current_module()
    @static if VERSION >= v"0.7.0-DEV.484"
        template(__source__, __module__, ex)
    else
        template(LineNumberNode(0), current_module(), ex)
    end
end

const TEMP_SYM = gensym("templates")

function template(src::LineNumberNode, mod::Module, ex::Expr)
    Meta.isexpr(ex, :(=), 2) || error("invalid `@template` syntax.")
    template(src, mod, ex.args[1], ex.args[2])
end

function template(source::LineNumberNode, mod::Module, tuple::Expr, docstr::Union{Symbol, Expr})
    Meta.isexpr(tuple, :tuple) || error("invalid `@template` syntax on LHS.")
    isdefined(mod, TEMP_SYM) || Core.eval(mod, :(const $(TEMP_SYM) = $(Dict{Symbol, Vector}())))
    local block = Expr(:block)
    for category in tuple.args
        local key = Meta.quot(category)
        local vec = Meta.isexpr(docstr, :string) ?
            Expr(:vect, docstr.args...) : :($(docstr).$(TEMP_SYM)[$(key)])
        push!(block.args, :($(TEMP_SYM)[$(key)] = $(vec)))
    end
    push!(block.args, nothing)
    return esc(block)
end

function template(src::LineNumberNode, mod::Module, sym::Symbol, docstr::Union{Symbol, Expr})
    template(src, mod, Expr(:tuple, sym), docstr)
end

# The signature for the atdocs() calls changed in v0.7
# On v0.6 and below it seems it was assumed to be (docstr::String, expr::Expr), but on v0.7
# it is (source::LineNumberNode, mod::Module, docstr::String, expr::Expr)
function template_hook(source::LineNumberNode, mod::Module, docstr, expr::Expr)
    local docex = interp_string(docstr)
    if isdefined(mod, TEMP_SYM) && Meta.isexpr(docex, :string)
        local templates = getfield(mod, TEMP_SYM)
        local template = get_template(templates, expression_type(expr))
        local out = Expr(:string)
        for t in template
            t == DOCSTRING ? append!(out.args, docex.args) : push!(out.args, t)
        end
        return (source, mod, out, expr)
    else
        return (source, mod, docstr, expr)
    end
end

function template_hook(docstr, expr::Expr)
    source, mod, docstr, expr::Expr = template_hook(LineNumberNode(0), current_module(), docstr, expr)
    docstr, expr
end

template_hook(args...) = args

interp_string(str::AbstractString) = Expr(:string, str)
interp_string(other) = other

get_template(t::Dict, k::Symbol) = haskey(t, k) ? t[k] : get(t, :DEFAULT, Any[DOCSTRING])

function expression_type(ex::Expr)
    # Expression heads changed in JuliaLang/julia/pull/23157 to match the new keyword syntax.
    if VERSION < v"0.7.0-DEV.1263" && Meta.isexpr(ex, [:type, :bitstype])
        :TYPES
    elseif Meta.isexpr(ex, :module)
        :MODULES
    elseif Meta.isexpr(ex, [:struct, :abstract, :typealias, :primitive])
        :TYPES
    elseif Meta.isexpr(ex, :macro)
        :MACROS
    elseif Meta.isexpr(ex, [:function, :(=)]) && Meta.isexpr(ex.args[1], :call) || (Meta.isexpr(ex.args[1], :where) && Meta.isexpr(ex.args[1].args[1], :call))
        :METHODS
    elseif Meta.isexpr(ex, :function)
        :FUNCTIONS
    elseif Meta.isexpr(ex, [:const, :(=)])
        :CONSTANTS
    else
        :DEFAULT
    end
end
expression_type(other) = :DEFAULT
