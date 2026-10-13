"""
$(:SIGNATURES)

Decides whether a length of method is too big to be visually appealing.
"""
method_length_over_limit(len::Int) = len > 60

function printmethod_format(buffer::IOBuffer, binding::String, args::Vector{String}, kws::Vector{String}; where_clause = "", return_type = "")

    sep_delim = " "
    paren_delim = ""
    indent = ""

    if method_length_over_limit(
            length(binding) +
            1 +
            sum(length.(args)) +
            sum(length.(kws)) +
            2*max(0, length(args)-1) +
            2*length(kws) +
            1 +
            length(where_clause) +
            length(return_type))

        sep_delim = "\n"
        paren_delim = "\n"
        indent = "    "
    end

    print(buffer, binding)
    print(buffer, "($paren_delim")
    join(buffer, Ref(indent).*args, ",$sep_delim")
    if !isempty(kws)
        print(buffer, ";$sep_delim")
        join(buffer, Ref(indent).*kws, ",$sep_delim")
    end
    print(buffer, "$paren_delim)")
    print(buffer, where_clause)
    print(buffer, return_type)
    return buffer
end

"""
$(:SIGNATURES)

Print a simplified representation of a method signature to `buffer`. Some of these
simplifications include:

  * no `TypeVar`s;
  * no types, except `::T` for an unnamed argument of type `T`;
  * no default values, unless `definition` gives them;
  * `_` printed for untyped unnamed arguments, and for destructured arguments unless
    `definition` gives them.

`definition` is the [`DefinitionArguments`](@ref) of the documented method definition, or
`nothing`. `returns` selects the [`return_annotation`](@ref) after the signature.

# Examples

```julia
f(x; a = 1, b...) = x
sig = printmethod(Docs.Binding(Main, :f), f, first(methods(f)))
```
"""
function printmethod(buffer::IOBuffer, binding::Docs.Binding, func, method::Method; definition = nothing, returns = false, brackets = false)
    local env = unionall_env(typevars(method.sig))
    typestring(t) = sprint(show, t; context = env)
    local names = argument_names(method, definition)
    local args = map(names, argument_types(method, length(names))) do arg, t
        arg == "_" && t !== Any ? "::$(typestring(t))" : arg
    end
    method.isva && (args[end] *= "...")
    local kws = string.(keywords(func, method))
    args, kws = append_defaults(args, kws, kws, method, definition; brackets = brackets)
    local name = callable_name(binding, constructor_parameters(method), typestring)
    local return_type = return_annotation(returns, func, method, argsig(method))
    return printmethod_format(buffer, name, args, kws; return_type = return_type)
end

"""
$(:SIGNATURES)

The positional argument names of `method`, with each destructured argument written as it
appears in `definition`.
"""
function argument_names(method::Method, definition)
    local args = string.(arguments(method))
    matches_definition(method, definition) || return args
    return map(enumerate(args)) do (i, arg)
        name, _ = definition.positional[i]
        arg == "_" ? name : arg
    end
end

"""
$(:SIGNATURES)

Whether `method` takes the positional arguments of `definition`, or a leading subset of
them.
"""
matches_definition(::Method, ::Nothing) = false
function matches_definition(method::Method, definition::DefinitionArguments)
    local names = string.(arguments(method))
    length(names) <= length(definition.positional) || return false
    # `_` stands for an argument whose name one side does not know, such as `@nospecialize(x)`.
    return all(zip(names, definition.positional)) do (name, (expected, _))
        name == "_" || expected == "_" || name == expected
    end
end

"""
$(:SIGNATURES)

Append `=default` to each formatted argument in `args` and keyword in `kws` that has a
default value in `definition`. `kwnames` names the keyword formatted in each entry of
`kws`. With `brackets` set, wrap each positional argument that has a default in brackets
and leave `kws` unchanged. Leaves both unchanged when `method` does not match `definition`.
"""
function append_defaults(args, kws, kwnames, method::Method, definition; brackets::Bool = false)
    matches_definition(method, definition) || return args, kws
    args = map(enumerate(args)) do (i, arg)
        _, default = definition.positional[i]
        default === nothing ? arg : brackets ? "[$arg]" : "$arg=$default"
    end
    brackets && return args, kws
    kws = map(kws, kwnames) do kw, name
        default = get(definition.keywords, name, nothing)
        default === nothing ? kw : "$kw=$default"
    end
    return args, kws
end

"""
$(:TYPEDSIGNATURES)

Print a method signature to `buffer` with the argument types from `typesig` and the declared
types of the keyword arguments, followed by the return annotation that `returns` selects (see
[`return_annotation`](@ref)). Type parameters keep their names and are declared in a `where`
clause after the arguments. Default values are left out unless `definition` gives them.

`definition` is as for the untyped `printmethod`.

# Examples

```julia
f(x::Int; a = 1, b...) = x
sig = printmethod(Docs.Binding(Main, :f), f, first(methods(f)))
```
"""
function printmethod(buffer::IOBuffer, binding::Docs.Binding, func, method::Method, typesig; returns=true, definition=nothing, brackets=false)
    # TODO: print qualified?
    local args = argument_names(method, definition)
    local kwnames = string.(keywords(func, method))

    local body = Base.unwrap_unionall(typesig)
    body isa DataType && body <: Tuple ||
        error("Expected `typeof($body)` to be `Tuple` or `UnionAll` but found `$(typeof(body))`")
    local params = constructor_parameters(method)
    local vars = params === nothing ? typevars(typesig) : [typevars(method.sig); typevars(self_type(method))]
    local kwtypes, kwvars = keyword_types(method, kwnames, vars)
    # Innermost first: a type parameter used only in a later parameter's bound is still used.
    local used = Any[]
    for v in reverse([vars; kwvars])
        if Base.has_typevar(body, v) || params !== nothing && any(p -> Base.has_typevar(p, v), params) ||
                any(t -> Base.has_typevar(t, v), values(kwtypes)) ||
                any(u -> Base.has_typevar(u.lb, v) || Base.has_typevar(u.ub, v), used)
            pushfirst!(used, v)
        end
    end
    local env = unionall_env(used)
    typestring(t) = sprint(show, t; context = env)

    argtypes = collect(body.types)
    if expanded_vararg(method)
        local n = length(argtypes) - length(args) + 1
        # `Vararg{T,0}` leaves no `T` in the signature.
        argtypes = Any[argtypes[1:end-n]..., Vararg{n > 0 ? argtypes[end] : Any, n}]
    end

    args = map(args, argtypes) do arg,t
        type = ""
        suffix = ""
        if Base.isvarargtype(t)
            local n = vararg_length(t)
            t = Base.unwrapva(t)
            if n === nothing
                suffix = "..."
            else
                type = "::Vararg{$(typestring(t)), $n}"
            end
        end
        if t!==Any && isempty(type)
            type = "::$(typestring(t))"
        end
        # An unnamed argument with a type prints as `::T`.
        if arg == "_" && !isempty(type)
            arg = ""
        end

        "$arg$type$suffix"
    end
    local kws = map(kwnames) do kw
        local t = get(kwtypes, kw, Any)
        t === Any ? kw : "$kw::$(typestring(t))"
    end
    args, kws = append_defaults(args, kws, kwnames, method, definition; brackets = brackets)

    return printmethod_format(
        buffer,
        callable_name(binding, params, typestring),
        args,
        kws;
        where_clause=where_clause(used),
        return_type=return_annotation(returns, func, method, typesig)
    )
end

"""
$(:SIGNATURES)

The ` -> T` that follows a signature. `returns` is `true` for the type that `method` is
inferred to return for `typesig`, `false` for none, or the text to print as `T`.
"""
return_annotation(returns::String, func, method::Method, typesig) = " -> $returns"

function return_annotation(returns::Bool, func, method::Method, typesig)
    returns || return ""
    local rt = method_return_type(func, method, typesig)
    return isempty(rt) || rt[1] === Nothing || rt[1] === Union{} ? "" : " -> $(rt[1])"
end

printmethod(b, f, m) = String(take!(printmethod(IOBuffer(), b, f, m)))

where_clause(typevars) =
    isempty(typevars) ? "" :
    length(typevars) == 1 ? " where $(typevars[1])" :
    " where {$(join(typevars, ", "))}"

# An `IOContext` in which `show` prints each of `typevars` by name.
unionall_env(typevars) = foldl((io, v) -> IOContext(io, :unionall_env => v), typevars; init = IOContext(devnull))

# The name `method` is called by, with the parameters of a constructor written as `T{P}(...)`.
callable_name(binding, params, typestring) =
    params === nothing ? string(binding.var) : string(binding.var, "{", join(map(typestring, params), ", "), "}")
