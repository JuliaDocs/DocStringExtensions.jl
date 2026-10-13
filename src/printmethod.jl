"""
$(:SIGNATURES)

Decides whether a length of method is too big to be visually appealing.
"""
method_length_over_limit(len::Int) = len > 60

function printmethod_format(buffer::IOBuffer, binding::String, args::Vector{String}, kws::Vector{String}; where_clause = "", return_type = "", macrocall = false)
    # A macro call separates its arguments with spaces and stays on one line, as in `@time ex`.
    if macrocall
        join(buffer, [binding; args], " ")
        print(buffer, where_clause, return_type)
        return buffer
    end

    sep_delim = " "
    paren_delim = ""
    indent = ""

    if method_length_over_limit(
            length(binding) +
                1 +
                sum(length.(args)) +
                sum(length.(kws)) +
                2 * max(0, length(args) - 1) +
                2 * length(kws) +
                1 +
                length(where_clause) +
                length(return_type)
        )

        sep_delim = "\n"
        paren_delim = "\n"
        indent = "    "
    end

    print(buffer, binding)
    print(buffer, "($paren_delim")
    join(buffer, Ref(indent) .* args, ",$sep_delim")
    if !isempty(kws)
        print(buffer, ";$sep_delim")
        join(buffer, Ref(indent) .* kws, ",$sep_delim")
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

```julia
f(x; a = 1, b...) = x
sig = printmethod(Docs.Binding(Main, :f), f, first(methods(f)))
```
"""
function printmethod(buffer::IOBuffer, binding::Docs.Binding, func, method::Method; definition = nothing, returns = false, brackets = false)
    aliases = alias_context(method.module)
    env = unionall_env(typevars(method.sig), aliases)
    typestring(t) = type_text(t, env)
    names = argument_names(method, definition)
    args = map(names, argument_types(method, length(names))) do arg, t
        arg == "_" && t !== Any ? "::$(typestring(t))" : arg
    end
    method.isva && (args[end] *= "...")
    kws = string.(keywords(func, method))
    args, kws = append_defaults(args, kws, kws, method, definition; brackets = brackets)
    instance = instance_type(func, method)
    vars = String[]
    name = if instance === nothing
        callable_name(binding, constructor_parameters(func, method), typestring)
    elseif func === Type
        # The binding `Type` does not say which types the callable takes, so print them as
        # their module names them, with any type parameter they use.
        used = used_typevars(typevars(method.sig), [instance])
        context = :module => method.module
        vars = String[typevar_text(v, IOContext(aliases, context)) for v in used]
        instance_call(method, type_text(instance, IOContext(unionall_env(used, aliases), context)))
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
    names = arguments(method)
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
    types = Any[body; collect(values(kwtypes))]
    params === nothing || append!(types, params)
    instance === nothing || push!(types, instance)
    used = used_typevars([vars; kwvars], types)
    aliases = alias_context(method.module)
    env = unionall_env(used, aliases)
    typestring(t) = type_text(t, env)

    argtypes = collect(body.types)
    if expanded_vararg(method)
        n = length(argtypes) - length(args) + 1
        # `Vararg{T,0}` leaves no `T` in the signature.
        argtypes = Any[argtypes[1:(end - n)]..., Vararg{n > 0 ? argtypes[end] : Any, n}]
    end

    args = map((arg, t) -> typed_argument(arg, t, typestring), args, argtypes)
    kws = map(kwnames) do kw
        t = get(kwtypes, kw, Any)
        t === Any ? kw : "$kw::$(typestring(t))"
    end
    args, kws = append_defaults(args, kws, kwnames, method, definition; brackets = brackets)

    return printmethod_format(
        buffer,
        instance === nothing ? callable_name(binding, params, typestring) : instance_call(method, typestring(instance)),
        args,
        kws;
        where_clause = where_clause([typevar_text(v, aliases) for v in used]),
        return_type = return_annotation(returns, func, method, typesig),
        macrocall = ismacro(method)
    )
end

# The type variables among `vars` that appear in `types` or in the bounds of another used one.
function used_typevars(vars, types)
    # Innermost first: a type parameter used only in a later parameter's bound is still used.
    used = Any[]
    for v in reverse(vars)
        isanonymous(v) && continue
        if any(t -> Base.has_typevar(t, v), types) ||
                any(u -> Base.has_typevar(u.lb, v) || Base.has_typevar(u.ub, v), used)
            pushfirst!(used, v)
        end
    end
    return used
end

# Whether `v` is a type variable Julia generated for a parameter written `<:T` or `>:T`, such
# as `var"#s1"` in `Vector{var"#s1"} where var"#s1"<:Real` for `Vector{<:Real}`.
isanonymous(v::TypeVar) = startswith(string(v.name), "#")

# `t` as `show` prints it in `io`, with each anonymous type variable that `show` would print by
# its generated name written as its bound, as in `Vector{<:Real}`. `show` prints the generated
# name before Julia 1.7, and inside `Type{<:T}` on 1.14.
function type_text(@nospecialize(t), io::IO)
    names = Pair{TypeVar, String}[]
    return named_text(name_anonymous!(names, t, io), names, io)
end

# `v` with its bounds, as a `where` clause declares it, with each bound written as `type_text`
# prints it in `io`. `show` would print only the name of a `v` in the `:unionall_env` of `io`.
function typevar_text(v::TypeVar, io::IO)
    name = sprint(show, TypeVar(v.name))
    lb = v.lb === Union{} ? nothing : where_bound(v.lb, io)
    ub = v.ub === Any ? nothing : where_bound(v.ub, io)
    lb === nothing && ub === nothing && return name
    lb === nothing && return string(name, "<:", ub)
    ub === nothing && return string(name, ">:", lb)
    return string(lb, "<:", name, "<:", ub)
end

# `bound` as `type_text` prints it, in parentheses only when its own `where` needs them, as in
# `T<:(Pair{S, S} where S)`. `show` puts every `UnionAll` bound in parentheses.
function where_bound(@nospecialize(bound), io::IO)
    text = type_text(bound, io)
    return toplevel_where(text) ? string("(", text, ")") : text
end

# Whether `text` has a `where` outside any brackets, as `Pair{S, S} where S` does.
function toplevel_where(text::AbstractString)
    depth = 0
    for (i, c) in pairs(text)
        depth += (c == '{' || c == '(') - (c == '}' || c == ')')
        depth == 0 && startswith(SubString(text, i), " where ") && return true
    end
    return false
end

# `t` as `show` prints it in `io`, with each free type variable of `names` written as its text.
function named_text(@nospecialize(t), names, io::IO)
    text = sprint(show, t; context = unionall_env(map(first, names), io))
    # Last first, so that the first placeholder is not replaced inside the tenth.
    for (v, replacement) in reverse(names)
        text = replace(text, string(v.name) => replacement)
    end
    return text
end

# `t` with each anonymous type variable that `show` prints by its generated name in `io` replaced
# by a free one that `show` prints by its name when it is in the `:unionall_env`. Appends each
# replacement to `names` with its text: its bound when `writes_as_bound`, as in `<:Real`.
# Otherwise the `UnionAll` it belongs to, written as the alias it came from. A variable that
# neither writes stays as `show` prints it.
function name_anonymous!(names, @nospecialize(t), io::IO)
    if t isa UnionAll
        isanonymous(t.var) || return UnionAll(t.var, name_anonymous!(names, t.body, io))
        body = Base.unwrap_unionall(t)
        # `Ref{<:Any}` is `Ref`, which `show` prints bare on every version.
        body isa DataType && t == body.name.wrapper && return body.name.wrapper
        occursin(string(t.var.name), sprint(show, t; context = io)) || return t
        placeholder = Symbol("DocStringExtensions_anonymous_", length(names) + 1)
        if writes_as_bound(t)
            v = TypeVar(placeholder, t.var.lb, t.var.ub)
            push!(names, v => bound_text(v, io))
            return name_anonymous!(names, t{v}, io)
        end
        text = alias_text(t, unionall_env(map(first, names), io))
        text === nothing && return t
        # A placeholder for the whole `UnionAll`: Julia caches a type such as `Ref{X}` by type
        # equality, so `Ref{X}` rebuilt from a renamed `X` comes back with the generated name.
        v = TypeVar(placeholder, Union{}, t)
        push!(names, v => text)
        return v
    elseif t isa Union
        return Union{name_anonymous!(names, t.a, io), name_anonymous!(names, t.b, io)}
    elseif t isa DataType
        params = Any[name_anonymous!(names, p, io) for p in t.parameters]
        return all(map(===, params, collect(t.parameters))) ? t : t.name.wrapper{params...}
    elseif istypeoftype(t)
        # From Julia 1.14 `Type{T}` is a `TypeEq`, not a `DataType`.
        p = name_anonymous!(names, type_parameter(t), io)
        return p === type_parameter(t) ? t : Type{p}
    elseif Base.isvarargtype(t)
        # From Julia 1.7 a `Vararg` is neither a `DataType` nor a `UnionAll`.
        n = vararg_length(t)
        element = name_anonymous!(names, Base.unwrapva(t), io)
        return n === nothing ? Vararg{element} : Vararg{element, n}
    end
    return t
end

# The anonymous variable `v` written as its bound, `<:Upper` or `>:Lower`.
bound_text(v::TypeVar, io::IO) = v.lb === Union{} ? "<:" * type_text(v.ub, io) : ">:" * type_text(v.lb, io)

# Whether the variable of `t` means the same written as its bound, as in `Vector{<:Real}`: it is
# a parameter of the type that `t` wraps, and appears nowhere else.
function writes_as_bound(t::UnionAll)
    v = t.var
    body = t.body
    while body isa UnionAll
        (Base.has_typevar(body.var.lb, v) || Base.has_typevar(body.var.ub, v)) && return false
        body = body.body
    end
    istypeoftype(body) && return type_parameter(body) === v
    body isa DataType || return false
    return count(p -> p === v, body.parameters) == 1 && count(p -> Base.has_typevar(p, v), body.parameters) == 1
end

# `io` extended so that `type_text` also looks for aliases in `mod`, the module that defines
# what a docstring documents.
alias_context(mod::Module, io::IO = devnull) = IOContext(io, :DocStringExtensions_module => mod)

# `t`, a `UnionAll` over anonymous type variables, written as the `const` alias that gives it,
# such as `ScalarOrRef{<:AbstractFloat}` for `const ScalarOrRef{T} = Union{T, Ref{T}} where T`,
# or `nothing` when no alias does. Aliases in the docstring's module come first, then those of
# its parents, nearest first, then those with fewer parameters, then by name.
function alias_text(t::UnionAll, io::IO)
    home = get(io, :DocStringExtensions_module, nothing)
    mods, nested = alias_modules(t, home)
    best = nothing
    for (i, mod) in enumerate(mods), name in module_aliases(mod)
        alias = Base.invokelatest(getfield, mod, name)
        args = alias_arguments(alias, t)
        args === nothing && continue
        # An imported alias is named by the module that defines it.
        owner = Base.invokelatest(which, mod, name)
        rank = (min(i, nested + 1), length(args), string(name), string(owner))
        (best === nothing || isless(rank, best[1])) && (best = (rank, owner, name, args))
    end
    best === nothing && return nothing
    _, mod, name, args = best
    anonymous, _ = leading_anonymous(t)
    texts = map(args) do arg
        i = findfirst(v -> v === arg, anonymous)
        i === nothing ? type_text(arg, io) : bound_text(anonymous[i], io)
    end
    return string(alias_name(mod, name, io), "{", join(texts, ", "), "}")
end

# The modules to look for an alias of `t` in, and how many of them come from `home`: `home` and
# its parents, nearest first, then the module of each type `t` names. Like `show`, it looks for
# an alias of a type from `Core` in `Base`.
function alias_modules(@nospecialize(t), home)
    mods = Module[]
    mod = home
    while mod isa Module && !(mod in mods)
        push!(mods, mod)
        mod = parentmodule(mod)
    end
    nested = length(mods)
    foreach_type(t) do part
        mod = part isa DataType ? parentmodule(part) : istypeoftype(part) ? Core : nothing
        mod === nothing || mod in mods || push!(mods, mod)
    end
    Core in mods && !(Base in mods) && push!(mods, Base)
    return mods, nested
end

# Calls `f` on `t` and on every type inside it: bounds, bodies, `Union` members and parameters.
function foreach_type(f, @nospecialize(t))
    f(t)
    if t isa UnionAll
        foreach_type(f, t.var.lb)
        foreach_type(f, t.var.ub)
        foreach_type(f, t.body)
    elseif t isa Union
        foreach_type(f, t.a)
        foreach_type(f, t.b)
    elseif t isa DataType
        foreach(p -> foreach_type(f, p), t.parameters)
    elseif istypeoftype(t)
        foreach_type(f, type_parameter(t))
    elseif Base.isvarargtype(t)
        foreach_type(f, Base.unwrapva(t))
    end
    return nothing
end

# Whether `text`, which `type_text` printed for `t`, still shows a name Julia generated for one of
# the type variables of `t`.
function shows_anonymous(@nospecialize(t), text)
    anonymous = Symbol[]
    foreach_type(part -> part isa UnionAll && isanonymous(part.var) && push!(anonymous, part.var.name), t)
    return any(name -> occursin(string(name), text), anonymous)
end

# The name of the alias `name` of `mod` as `show` writes a type name in `io`: bare when it is
# visible from the `:module` of `io`, which defaults to `Main`, and qualified otherwise.
function alias_name(mod::Module, name::Symbol, io::IO)
    from = get(io, :module, Main)
    visible = from isa Module && Base.invokelatest(isdefined, from, name) &&
        Base.invokelatest(getfield, from, name) === Base.invokelatest(getfield, mod, name)
    return visible ? string(name) : string(mod, ".", name)
end

# The names of the `const` aliases of `mod`, with those it imports. Not cached: before Julia 1.12
# defining a `const` leaves the world counter alone, so nothing would tell a cache that `mod`
# gained an alias.
module_aliases(mod::Module) = filter(
    name -> Base.invokelatest(isalias, mod, name),
    Base.invokelatest(names, mod; all = true, imported = true)
)

# Whether `name` is a `const` of `mod` bound to a parametric alias, such as `Vector` or
# `const ScalarOrRef{T} = Union{T, Ref{T}} where T`, and not to a type's own `UnionAll`.
function isalias(mod::Module, name::Symbol)
    isdefined(mod, name) && !Base.isdeprecated(mod, name) && isconst(mod, name) || return false
    value = getfield(mod, name)
    value isa UnionAll || return false
    body = Base.unwrap_unionall(value)
    return !(body isa DataType && value === body.name.wrapper)
end

# The arguments that `alias` applies to give `t`, with each anonymous type variable of `t` as one
# whole argument, or `nothing` when `alias` does not give `t`.
function alias_arguments(@nospecialize(alias), t::UnionAll)
    alias isa UnionAll || return nothing
    anonymous, body = leading_anonymous(t)
    vars = typevars(alias)
    args = Vector{Any}(undef, length(vars))
    match_alias!(args, vars, Base.unwrap_unionall(alias), body) || return nothing
    all(i -> isassigned(args, i), eachindex(args)) || return nothing
    for v in anonymous
        count(arg -> arg === v, args) == 1 || return nothing
        any(arg -> arg !== v && Base.has_typevar(arg, v), args) && return nothing
    end
    # The match reads `t` structurally, so only an alias that rebuilds `t` gives it. Julia
    # applies an alias to a type variable outside its bounds without complaint, so `t` must also
    # be a subtype of the alias.
    fresh = Dict{TypeVar, TypeVar}(v => TypeVar(v.name, v.lb, v.ub) for v in anonymous)
    applied = try
        alias{Any[arg isa TypeVar ? get(fresh, arg, arg) : arg for arg in args]...}
    catch err
        err isa TypeError || rethrow()
        return nothing
    end
    for v in reverse(anonymous)
        applied = UnionAll(fresh[v], applied)
    end
    return applied == t && t <: alias ? args : nothing
end

# The anonymous type variables that `t` declares first, outermost first, and the rest of `t`.
function leading_anonymous(t::UnionAll)
    anonymous = TypeVar[]
    body = t
    while body isa UnionAll && isanonymous(body.var)
        push!(anonymous, body.var)
        body = body.body
    end
    return anonymous, body
end

# Binds `args[i]` to the part of `t` in the place of `vars[i]` within `pattern`, and whether
# `pattern` reads as `t` with those bindings. A variable bound twice must bind equal parts.
function match_alias!(args, vars, @nospecialize(pattern), @nospecialize(t))
    if pattern isa TypeVar
        i = findfirst(v -> v === pattern, vars)
        i === nothing && return pattern === t
        isassigned(args, i) && return same_parameter(args[i], t)
        args[i] = t
        return true
    elseif pattern isa UnionAll
        t isa UnionAll || return false
        match_alias!(args, vars, pattern.var.lb, t.var.lb) || return false
        match_alias!(args, vars, pattern.var.ub, t.var.ub) || return false
        # The variable `pattern` binds stands for the one `t` binds, within the body.
        inner = Vector{Any}(undef, length(args) + 1)
        foreach(i -> isassigned(args, i) && (inner[i] = args[i]), eachindex(args))
        inner[end] = t.var
        match_alias!(inner, [vars; pattern.var], pattern.body, t.body) || return false
        foreach(i -> isassigned(inner, i) && (args[i] = inner[i]), eachindex(args))
        return true
    elseif pattern isa Union
        return t isa Union && match_alias!(args, vars, pattern.a, t.a) && match_alias!(args, vars, pattern.b, t.b)
    elseif pattern isa DataType
        t isa DataType && pattern.name === t.name && length(pattern.parameters) == length(t.parameters) ||
            return false
        return all(i -> match_alias!(args, vars, pattern.parameters[i], t.parameters[i]), eachindex(pattern.parameters))
    elseif istypeoftype(pattern)
        return istypeoftype(t) && match_alias!(args, vars, type_parameter(pattern), type_parameter(t))
    elseif Base.isvarargtype(pattern)
        Base.isvarargtype(t) && match_alias!(args, vars, Base.unwrapva(pattern), Base.unwrapva(t)) || return false
        isdefined(pattern, :N) == isdefined(t, :N) || return false
        return !isdefined(pattern, :N) || match_alias!(args, vars, pattern.N, t.N)
    end
    return same_parameter(pattern, t)
end

# Whether two type parameters are the same: identical, or equal types.
same_parameter(@nospecialize(a), @nospecialize(b)) = a === b || a isa Type && b isa Type && a == b

# The positional argument `arg` of type `t`, as the typed `printmethod` prints it.
function typed_argument(arg, t, typestring)
    type = ""
    suffix = ""
    if Base.isvarargtype(t)
        len = vararg_length(t)
        t = Base.unwrapva(t)
        if len === nothing
            suffix = "..."
        else
            type = "::Vararg{$(typestring(t)), $len}"
        end
    end
    if t !== Any && isempty(type)
        type = "::$(typestring(t))"
    end
    # An unnamed argument with a type prints as `::T`.
    if arg == "_" && !isempty(type)
        arg = ""
    end
    return "$arg$type$suffix"
end

"""
$(:SIGNATURES)

The ` -> T` that follows a signature. `returns` is `true` for the type that `method` is
inferred to return for `typesig`, `false` for none, or the text to print as `T`. An inferred
type that still shows a name Julia generated for a type variable is left out.
"""
return_annotation(returns::String, func, method::Method, typesig) = " -> $returns"

function return_annotation(returns::Bool, func, method::Method, typesig)
    # A macro returns the expression it generates, whose type tells the reader nothing.
    returns && !ismacro(method) || return ""
    rt = method_return_type(func, method, typesig)
    (isempty(rt) || rt[1] === Nothing || rt[1] === Union{}) && return ""
    text = type_text(rt[1], alias_context(method.module))
    # Inference leaves no source to write a generated type variable from.
    return shows_anonymous(rt[1], text) ? "" : " -> $text"
end

printmethod(b, f, m) = String(take!(printmethod(IOBuffer(), b, f, m)))

where_clause(typevars) =
    isempty(typevars) ? "" :
    length(typevars) == 1 ? " where $(typevars[1])" :
    " where {$(join(typevars, ", "))}"

# `io` extended so that `show` prints each of `typevars` by name.
unionall_env(typevars, io = IOContext(devnull)) = foldl((io, v) -> IOContext(io, :unionall_env => v), typevars; init = io)

# The name `method` is called by, with the parameters of a constructor written as `T{P}(...)`.
callable_name(binding, params, typestring) =
    params === nothing ? string(binding.var) : string(binding.var, "{", join(map(typestring, params), ", "), "}")

# The instance a callable method is called on, `(e::T)` or `(::T)`, with `type` printed for `T`.
function instance_call(method::Method, type)
    name = first(slot_names(method))
    return string("(", isunnamed(name) ? "" : name, "::", type, ")")
end
