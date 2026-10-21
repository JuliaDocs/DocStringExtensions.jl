function printmethod_format(buffer::IOBuffer, binding::String, args::Vector{String}, kws::Vector{String}; where_clause = "", return_type = "", macrocall = false)
    # A macro call separates its arguments with spaces and stays on one line, as in `@time ex`.
    if macrocall
        join(buffer, [binding; args], " ")
    else
        call = sprint(print_call, binding, args, kws, false)
        if length(call) + length(where_clause) + length(return_type) > signature_width()
            print_call(buffer, binding, args, kws, true)
        else
            print(buffer, call)
        end
    end
    print(buffer, where_clause, return_type)
    return buffer
end

# `binding(args; kws)` on one line, or with each argument on its own line when `multiline`.
function print_call(io::IO, binding, args, kws, multiline::Bool)
    # A call without arguments stays `f()`, however long what follows it.
    wrap = multiline && !(isempty(args) && isempty(kws))
    newline, sep, indent = wrap ? ("\n", "\n", "    ") : ("", " ", "")
    print(io, binding, "(")
    # A keyword-only call keeps `;` on the first line, as in `f(;`.
    isempty(args) || print(io, newline)
    print_arguments(io, args, sep, indent)
    if !isempty(kws)
        print(io, ";", sep)
        print_arguments(io, kws, sep, indent)
    end
    print(io, newline, ")")
    return nothing
end

function print_arguments(io::IO, args, sep, indent)
    for (i, arg) in enumerate(args)
        i > 1 && print(io, ",", sep)
        print(io, indent, arg)
    end
    return nothing
end

"""
$(:SIGNATURES)

Print a simplified representation of a method signature to `buffer`. Some of these
simplifications include:

  * no `TypeVar`s, except those of a callable on `Type{T}`, such as
    `(::Type{T})(x) where T<:Number`;
  * no types, except `::T` for an unnamed argument of type `T`;
  * no default values, unless `definition` gives them;
  * `_` printed for untyped unnamed arguments, and for destructured arguments unless
    `definition` gives them;
  * a macro printed as its caller writes it, `@m a b`, without `__source__` and
    `__module__` or an inferred return type.

`definition` is the [`DefinitionArguments`](@ref) of the documented method definition, or
`nothing`. `returns` selects the [`return_annotation`](@ref) after the signature.

# Examples

```jldoctest
julia> f(x; a = 1, b...) = x;

julia> buffer = IOBuffer();

julia> DocStringExtensions.printmethod(buffer, Docs.Binding(@__MODULE__, :f), f, first(methods(f)));

julia> String(take!(buffer))
"f(x; a, b...)"
```
"""
function printmethod(buffer::IOBuffer, binding::Docs.Binding, func, method::Method; definition = nothing, returns = false, brackets = false)
    aliases = alias_context(method.module)
    env = unionall_env(typevars(method.sig), aliases)
    names = argument_names(method, definition)
    types = argument_types(method, length(names))
    args = String[]
    for i in eachindex(names)
        arg, t = names[i], types[i]
        push!(args, arg == "_" && t !== Any ? "::$(type_text(t, env))" : arg)
    end
    method.isva && (args[end] = "$(args[end])...")
    kws = string.(keywords(func, method))
    args, kws = append_defaults(args, kws, kws, method, definition; brackets = brackets)
    instance = instance_type(func, method)
    vars = String[]
    name = if instance === nothing
        callable_name(binding, constructor_parameters(func, method), env)
    elseif func === Type
        # The binding `Type` does not say which types the callable takes, so print them as
        # their module names them, with any type parameter they use.
        used = used_typevars(typevars(method.sig), [instance])
        env = IOContext(unionall_env(used, aliases), :module => method.module)
        vars = typevar_texts(used, env)
        instance_call(method, type_text(instance, env))
    else
        instance_call(method, string(binding.var))
    end
    return_type = return_annotation(returns, func, method, argsig(method))
    return printmethod_format(
        buffer, name, args, kws;
        where_clause = where_clause(vars), return_type = return_type, macrocall = ismacro(method)
    )
end

"""
$(:SIGNATURES)

The positional argument names of `method`, with each destructured argument written as it
appears in `definition`.
"""
function argument_names(method::Method, definition)
    args = arguments(method)
    matches_definition(method, definition) || return args
    names = String[]
    for i in eachindex(args)
        name, _ = definition.positional[i]
        push!(names, args[i] == "_" ? name : args[i])
    end
    return names
end

"""
$(:SIGNATURES)

Whether `method` takes the positional arguments of `definition`, or a leading subset of
them.
"""
matches_definition(::Method, ::Nothing) = false
function matches_definition(method::Method, definition::DefinitionArguments)
    names = arguments(method)
    length(names) <= length(definition.positional) || return false
    # `_` stands for an argument whose name one side does not know, such as `@nospecialize(x)`.
    for i in eachindex(names)
        name = names[i]
        expected, _ = definition.positional[i]
        name == "_" || expected == "_" || name == expected || return false
    end
    return true
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
    with_defaults = String[]
    for i in eachindex(args)
        arg = args[i]
        _, default = definition.positional[i]
        push!(with_defaults, default === nothing ? arg : brackets ? "[$arg]" : "$arg=$default")
    end
    brackets && return with_defaults, kws
    kws_with_defaults = String[]
    for i in eachindex(kws)
        kw = kws[i]
        default = get(definition.keywords, kwnames[i], nothing)
        push!(kws_with_defaults, default === nothing ? kw : "$kw=$default")
    end
    return with_defaults, kws_with_defaults
end

"""
$(:TYPEDSIGNATURES)

Print a method signature to `buffer` with the argument types from `typesig` and the declared
types of the keyword arguments, followed by the return annotation that `returns` selects (see
[`return_annotation`](@ref)). Type parameters keep their names and are declared in a `where`
clause after the arguments. Default values are left out unless `definition` gives them.

`definition` is as for the untyped `printmethod`.

# Examples

```jldoctest
julia> f(x::Int; a = 1, b...) = x;

julia> buffer = IOBuffer();

julia> DocStringExtensions.printmethod(buffer, Docs.Binding(@__MODULE__, :f), f, first(methods(f)), Tuple{Int});

julia> String(take!(buffer))
"f(x::Int64; a, b...) -> Int64"
```
"""
function printmethod(buffer::IOBuffer, binding::Docs.Binding, func, method::Method, typesig; returns = true, definition = nothing, brackets = false)
    args = argument_names(method, definition)
    kwnames = string.(keywords(func, method))

    body = Base.unwrap_unionall(typesig)
    body isa DataType && body <: Tuple ||
        error("Expected `typeof($body)` to be `Tuple` or `UnionAll` but found `$(typeof(body))`")
    params = constructor_parameters(func, method)
    instance = instance_type(func, method)
    vars = params === nothing && instance === nothing ? typevars(typesig) :
        [typevars(method.sig); typevars(self_type(method))]
    kwtypes, kwvars = keyword_types(method, kwnames, vars)
    types = Any[body]
    append!(types, values(kwtypes))
    params === nothing || append!(types, params)
    instance === nothing || push!(types, instance)
    used = used_typevars([vars; kwvars], types)
    aliases = alias_context(method.module)
    env = unionall_env(used, aliases)

    argtypes = collect(body.types)
    if expanded_vararg(method)
        n = length(argtypes) - length(args) + 1
        # `Vararg{T,0}` leaves no `T` in the signature.
        argtypes = Any[argtypes[1:(end - n)]..., Vararg{n > 0 ? argtypes[end] : Any, n}]
    end

    typed = String[]
    for i in eachindex(args)
        push!(typed, typed_argument(args[i], argtypes[i], env))
    end
    kws = String[]
    for kw in kwnames
        t = get(kwtypes, kw, Any)
        push!(kws, t === Any ? kw : "$kw::$(type_text(t, env))")
    end
    args, kws = append_defaults(typed, kws, kwnames, method, definition; brackets = brackets)

    return printmethod_format(
        buffer,
        instance === nothing ? callable_name(binding, params, env) : instance_call(method, type_text(instance, env)),
        args,
        kws;
        where_clause = where_clause(typevar_texts(used, env)),
        return_type = return_annotation(returns, func, method, typesig),
        macrocall = ismacro(method)
    )
end

# The type variables among `vars` that appear in `types` or in the bounds of another used one.
function used_typevars(vars, types)
    # Innermost first: a type parameter used only in a later parameter's bound is still used.
    used = Any[]
    for i in length(vars):-1:1
        v = vars[i]
        isanonymous(v) && continue
        (has_typevar_in(types, v) || bounds_have_typevar(used, v)) && pushfirst!(used, v)
    end
    return used
end

function has_typevar_in(types, v::TypeVar)
    for t in types
        Base.has_typevar(t, v) && return true
    end
    return false
end

function bounds_have_typevar(vars, v::TypeVar)
    for u in vars
        (Base.has_typevar(u.lb, v) || Base.has_typevar(u.ub, v)) && return true
    end
    return false
end

# The positional argument `arg` of type `t`, as the typed `printmethod` prints it in `io`.
function typed_argument(arg, t, io)
    type = ""
    suffix = ""
    if Base.isvarargtype(t)
        len = vararg_length(t)
        t = Base.unwrapva(t)
        if len === nothing
            suffix = "..."
        else
            type = "::Vararg{$(type_text(t, io)), $len}"
        end
    end
    if t !== Any && isempty(type)
        type = "::$(type_text(t, io))"
    end
    # An unnamed argument with a type prints as `::T`.
    if arg == "_" && !isempty(type)
        arg = ""
    end
    return "$arg$type$suffix"
end

"""
$(:SIGNATURES)

The ` -> T` that follows a signature, with the [`return_arrow`](@ref). `returns` is `true`
for the type that `method` is inferred to return for `typesig`, `false` for none, or the text
to print as `T`. An inferred type that still shows a name Julia generated for a type variable
is left out.
"""
return_annotation(returns::String, func, method::Method, typesig) = " $(return_arrow()) $returns"

function return_annotation(returns::Bool, func, method::Method, typesig)
    # A macro returns the expression it generates, whose type tells the reader nothing.
    returns && !ismacro(method) || return ""
    rt = method_return_type(func, method, typesig)
    # `Any` says only that inference gave up.
    (isempty(rt) || rt[1] === Nothing || rt[1] === Union{} || rt[1] === Any) && return ""
    io = IOContext(alias_context(method.module), :DocStringExtensions_inferred => true)
    text = type_text(rt[1], io)
    # Inference leaves no source to write a generated type variable from.
    return shows_anonymous(rt[1], text, io) ? "" : return_annotation(text, func, method, typesig)
end

printmethod(b, f, m) = String(take!(printmethod(IOBuffer(), b, f, m)))

where_clause(typevars) =
    isempty(typevars) ? "" :
    length(typevars) == 1 ? " where $(typevars[1])" :
    " where {$(join(typevars, ", "))}"

function typevar_texts(vars, io)
    texts = String[]
    for v in vars
        push!(texts, typevar_text(v, io))
    end
    return texts
end

# The name `method` is called by, with the parameters of a constructor written as `T{P}(...)`.
function callable_name(binding, params, io)
    params === nothing && return string(binding.var)
    texts = String[]
    for p in params
        push!(texts, type_text(p, io))
    end
    return "$(binding.var){$(join(texts, ", "))}"
end

# The instance a callable method is called on, `(e::T)` or `(::T)`, with `type` printed for `T`.
function instance_call(method::Method, type)
    name = first(slot_names(method))
    instance = isunnamed(name) ? "" : name
    return "($instance::$type)"
end
