"""
The positional and keyword arguments of a documented method definition, rendered as source
text.

`positional` has a `(name, default)` entry for each positional argument, in order. `name` is
the argument's name, the destructuring of a destructured argument such as `"(a, b)"`, or
`"_"` for an unnamed argument. `default` is `nothing` when the argument has no default.
`keywords` maps the name of each keyword argument with a default to that default.
"""
struct DefinitionArguments
    positional::Vector{Tuple{String, Union{String, Nothing}}}
    keywords::Dict{String, String}
end

"""
$(:SIGNATURES)

Find the arguments of the method definition `expr`, with their default values when
`show_defaults` is set. Returns `nothing` when `expr` does not define a method, or when the
arguments would not change what a signature prints.
"""
function definition_arguments(expr::Expr, show_defaults::Bool)
    call = definition_call(expr)
    call === nothing && return nothing
    positional = Tuple{String, Union{String, Nothing}}[]
    keywords = Dict{String, String}()
    for arg in call.args[2:end]
        if Meta.isexpr(arg, :parameters)
            show_defaults || continue
            for kw in arg.args
                name, default = argument_default(kw)
                default === nothing || (keywords[name] = default)
            end
        else
            push!(positional, show_defaults ? argument_default(arg) : (argument_name(arg), nothing))
        end
    end
    # Without defaults, only a destructured argument prints differently from the method.
    show_defaults || any(arg -> startswith(first(arg), "("), positional) || return nothing
    return DefinitionArguments(positional, keywords)
end

function definition_call(expr::Expr)
    # A macro's arguments read as a function's do.
    definition = Meta.isexpr(expr, :macro) ? expr : method_definition(expr)
    return definition === nothing ? nothing : signature_call(definition.args[1])
end

"""
$(:SIGNATURES)

Render the body of the method definition `expr` as source text, one statement per line.
Returns `nothing` when `expr` does not define a method or the body is empty.
"""
function definition_body(expr::Expr)
    definition = method_definition(expr)
    (definition === nothing || definition_call(expr) === nothing) && return nothing
    body = without_linenums(definition.args[2])
    isempty(body.args) && return nothing
    # Base prints the block as `begin`, the statements indented by four spaces, then `end`.
    # Printing each statement alone mangles nested quotes.
    lines = split(sprint(print, body), '\n')[2:(end - 1)]
    return join([startswith(line, "    ") ? line[5:end] : line for line in lines], "\n")
end

# Line numbers would print the author's local file paths.
without_linenums(ex::Expr) = remove_macro_linenums!(Base.remove_linenums!(copy(ex)))
without_linenums(@nospecialize(other)) = other

# `remove_linenums!` keeps the line number that every macro call carries.
function remove_macro_linenums!(ex::Expr)
    Meta.isexpr(ex, :macrocall) && ex.args[2] isa LineNumberNode && (ex.args[2] = nothing)
    foreach(remove_macro_linenums!, ex.args)
    return ex
end
remove_macro_linenums!(@nospecialize(other)) = other

function method_definition(expr::Expr)
    Meta.isexpr(expr, :macrocall) && return method_definition(last(expr.args))
    (Meta.isexpr(expr, :function) || Meta.isexpr(expr, :(=))) && return expr
    return nothing
end
method_definition(@nospecialize(other)) = nothing

# Strips `where` clauses and a return type annotation from a method signature.
function signature_call(@nospecialize(sig))
    Meta.isexpr(sig, :call) && return sig
    Meta.isexpr(sig, :where) && return signature_call(sig.args[1])
    Meta.isexpr(sig, :(::), 2) && return signature_call(sig.args[1])
    return nothing
end

function argument_default(@nospecialize(arg))
    Meta.isexpr(arg, :kw, 2) && return (argument_name(arg.args[1]), source_text(arg.args[2]))
    return (argument_name(arg), nothing)
end

source_text(@nospecialize(ex)) = sprint(Base.show_unquoted, without_linenums(ex))

argument_name(name::Symbol) = string(name)
function argument_name(@nospecialize(arg))
    Meta.isexpr(arg, :kw, 2) && return argument_name(arg.args[1])
    Meta.isexpr(arg, :(::), 2) && return argument_name(arg.args[1])
    Meta.isexpr(arg, :..., 1) && return argument_name(arg.args[1])
    Meta.isexpr(arg, :tuple) && return sprint(Base.show_unquoted, arg)
    return "_"
end

"""
$(:SIGNATURES)

Find the default value of each field of the struct definition `expr`, rendered as source
text and keyed by field name. Defaults are written as `field = value` inside a macro such as
`Base.@kwdef`. Returns `nothing` when `expr` does not define a struct or no field has a
default.
"""
function field_defaults(expr::Expr)
    definition = struct_definition(expr)
    definition === nothing && return nothing
    defaults = add_field_defaults!(Dict{Symbol, String}(), definition.args[3])
    return isempty(defaults) ? nothing : defaults
end

function add_field_defaults!(defaults, body::Expr)
    for field in body.args
        if Meta.isexpr(field, :block)
            add_field_defaults!(defaults, field)
        else
            name, default = field_default(field)
            default === nothing || (defaults[name] = default)
        end
    end
    return defaults
end

function struct_definition(expr::Expr)
    Meta.isexpr(expr, :macrocall) && return struct_definition(last(expr.args))
    return Meta.isexpr(expr, :struct) ? expr : nothing
end
struct_definition(@nospecialize(other)) = nothing

function field_default(@nospecialize(field))
    Meta.isexpr(field, :const, 1) && return field_default(field.args[1])
    Meta.isexpr(field, :(=), 2) || return (nothing, nothing)
    name = field_name(field.args[1])
    name === nothing && return (nothing, nothing)
    return (name, source_text(without_tags(field.args[2])))
end

# An inner constructor's left-hand side is a call or a `where`, which has no field name.
field_name(name::Symbol) = name
function field_name(@nospecialize(ex))
    Meta.isexpr(ex, :(::), 2) && return field_name(ex.args[1])
    Meta.isexpr(ex, :macrocall) && ex.args[1] === Symbol("@atomic") && return field_name(last(ex.args))
    return nothing
end

# StructUtils.jl writes field tags after the default, as in `x::Int = 1 &(json = (name = "y",),)`.
function without_tags(@nospecialize(value))
    is_tagged = Meta.isexpr(value, :call, 3) && value.args[1] === :& && Meta.isexpr(value.args[3], :tuple)
    return is_tagged ? value.args[2] : value
end

"""
Where a documented struct definition ends, which bounds the constructors that its signatures
list.

$(:FIELDS)
"""
struct StructDefinition
    "The file the definition is written in."
    file::String
    "The last line of the definition's body."
    last_line::Int
    "Whether a macro wraps the definition, and so may define constructors outside its body."
    wrapped::Bool
end

"""
$(:SIGNATURES)

The [`StructDefinition`](@ref) of the struct that `expr` defines, or `nothing` when `expr`
does not define a struct or carries no line numbers.
"""
function struct_extent(expr::Expr)
    definition = struct_definition(expr)
    definition === nothing && return nothing
    # The docstring's own path is empty for `Base.@kwdef` on Julia 1.0.
    lines = line_numbers!(LineNumberNode[], definition)
    isempty(lines) && return nothing
    return StructDefinition(string(first(lines).file), maximum(l -> l.line, lines), definition !== expr)
end

function line_numbers!(lines, @nospecialize(ex))
    ex isa LineNumberNode && push!(lines, ex)
    ex isa Expr && foreach(arg -> line_numbers!(lines, arg), ex.args)
    return lines
end
