
#
# Utilities.
#

#
# Expression Capture.
#

"""
    interpolation(object::T, captured::Expr) -> new_object

Interface method for hooking into interpolation within docstrings to change
the behaviour of the interpolation. `object` is the interpolated object within a
docstring and `captured` is the raw expression that is documented by the docstring
in which the interpolated `object` has been included.

To define custom behaviour for your own `object` types implement a method of
`interpolation(::T, captured)` for type `T` and return a `new_object` to
be interpolated into the final docstring. Note that you must own the definition
of type `T`. `new_object` does not need to be of type `T`.
"""
interpolation(@nospecialize(object), @nospecialize(_)) = object

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

#
# Definition arguments.
#

"""
The positional and keyword arguments of a documented method definition, rendered as source
text.

`positional` has a `(name, default)` entry for each positional argument, in order. `name` is
the argument's name, the destructuring of a destructured argument such as `"(a, b)"`, or
`"_"` for an unnamed argument. `default` is `nothing` when the argument has no default.
`keywords` maps the name of each keyword argument with a default to that default.
"""
struct DefinitionArguments
    positional::Vector{Tuple{String,Union{String,Nothing}}}
    keywords::Dict{String,String}
end

"""
$(:SIGNATURES)

Find the arguments of the method definition `expr`, with their default values when
`show_defaults` is set. Returns `nothing` when `expr` does not define a method, or when the
arguments would not change what a signature prints.
"""
function definition_arguments(expr::Expr, show_defaults::Bool)
    local call = definition_call(expr)
    call === nothing && return nothing
    local positional = Tuple{String,Union{String,Nothing}}[]
    local keywords = Dict{String,String}()
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
    Meta.isexpr(expr, :macrocall) && return definition_call(last(expr.args))
    if Meta.isexpr(expr, :function) || Meta.isexpr(expr, :(=))
        return signature_call(expr.args[1])
    end
    return nothing
end
definition_call(@nospecialize(other)) = nothing

# Strips `where` clauses and a return type annotation from a method signature.
function signature_call(@nospecialize(sig))
    Meta.isexpr(sig, :call) && return sig
    Meta.isexpr(sig, :where) && return signature_call(sig.args[1])
    Meta.isexpr(sig, :(::), 2) && return signature_call(sig.args[1])
    return nothing
end

function argument_default(@nospecialize(arg))
    if Meta.isexpr(arg, :kw, 2)
        local default = arg.args[2]
        # Line numbers would print the author's local file paths.
        default isa Expr && (default = Base.remove_linenums!(copy(default)))
        return (argument_name(arg.args[1]), sprint(Base.show_unquoted, default))
    end
    return (argument_name(arg), nothing)
end

argument_name(name::Symbol) = string(name)
function argument_name(@nospecialize(arg))
    Meta.isexpr(arg, :kw, 2) && return argument_name(arg.args[1])
    Meta.isexpr(arg, :(::), 2) && return argument_name(arg.args[1])
    Meta.isexpr(arg, :..., 1) && return argument_name(arg.args[1])
    Meta.isexpr(arg, :tuple) && return sprint(Base.show_unquoted, arg)
    return "_"
end

#
# Method grouping.
#

"""
$(:SIGNATURES)

Group all methods of function `func` with type signatures `typesig` in module `modname`.
Keyword argument `exact = true` matches signatures "exactly" with `==` rather than `<:`.

# Examples

```julia
groups = methodgroups(f, Union{Tuple{Any}, Tuple{Any, Integer}}, Main; exact = false)
```
"""
function methodgroups(func, typesig, modname; exact = true)
    # Group methods by file and line number.
    local methods = getmethods(func, typesig)
    # A docstring on a constructor written as `T{P}(...)` documents a method of `Type{T{P}}`.
    if func isa UnionAll && typesig != Union{}
        methods = unique([methods; constructor_methods(func, typesig)])
    end
    local groups = groupby(Tuple{Symbol, Int}, Vector{Method}, methods) do m
        (m.file, m.line), m
    end

    # Filter out methods from other modules and with non-matching signatures.
    local typesigs = alltypesigs(typesig)
    local results = Vector{Method}[]
    for (key, group) in groups
        filter!(m -> m.module == modname, group)
        if exact
            # Julia 1.12 and later can normalise the union of a definition's signatures
            # into a single type, such as `Union{Tuple{}, Tuple{Any, Vararg{Any}}} == Tuple`.
            # When no method matches a component, keep the group if `typesig` covers it.
            # Subtyping cannot always prove the converse, as for `where T` outside a union.
            local matching = filter(m -> argsig(m) in typesigs, group)
            if !isempty(matching) || !all(m -> argsig(m) <: typesig, group)
                group = matching
            end
        end
        isempty(group) || push!(results, group)
    end

    # Sort the groups by file and line.
    sort!(results, lt = comparemethods, by = first)

    return results
end

"""
$(:SIGNATURES)

The group in `groups` that the docstring `doc` documents: the first defined at or after the
docstring in its file. The docsystem adds a `Tuple{T}` to the type signature for each `where T`,
which can match a method of another definition. All of `groups` when `doc` records no location or
no group follows it.
"""
function documented_groups(groups, doc)
    local path = get(doc.data, :path, nothing)
    local line = get(doc.data, :linenumber, nothing)
    (path === nothing || line === nothing) && return groups
    local after = filter(g -> String(first(g).file) == path && first(g).line >= line, groups)
    isempty(after) && return groups
    return [after[argmin(map(g -> first(g).line, after))]]
end

# The argument types of `m`, without the function's own type.
argsig(m::Method) = Base.rewrap_unionall(Base.tuple_type_tail(m.sig), m.sig)

"""
$(:SIGNATURES)

Compare methods `a` and `b` by file and line number.
"""
function comparemethods(a::Method, b::Method)
    comp = a.file < b.file ? -1 : a.file > b.file ? 1 : 0
    comp == 0 ? a.line < b.line : comp < 0
end

if isdefined(Base, :UnionAll)
    uniontypes(T) = uniontypes!(Any[], T)
    function uniontypes!(out, T)
        if isa(T, Union)
            push!(out, T.a)
            uniontypes!(out, T.b)
        else
            push!(out, T)
        end
        return out
    end
    gettype(T::UnionAll) = gettype(T.body)
else
    uniontypes(T) = collect(T.types)
end
gettype(other) = other

"""
$(:SIGNATURES)

A helper method for [`getmethods`](@ref) that collects methods in `results`.
"""
function getmethods!(results, f, sig)
    if sig == Union{}
        append!(results, Base.invokelatest(methods, f))
    else
        # Each signature keeps its `where` bounds: Julia 1.14 matches no method against a
        # type variable left free with a bound.
        for each in alltypesigs(sig)
            append!(results, Base.invokelatest(methods, f, each))
        end
    end
    return results
end

"""
$(:SIGNATURES)

Collect and return all methods of function `f` matching signature `sig`.

This is similar to `methods(f, sig)`, but handles type signatures found in `DocStr` objects
more consistently than `methods`.
"""
getmethods(f, sig) = unique(getmethods!(Method[], f, sig))

"""
$(:SIGNATURES)

The methods of `Type{T}`, for `T` any instance of the parametric type `func`, whose
arguments match `typesig`. These are the constructors written as `T{P}(...)`.
"""
function constructor_methods(func::UnionAll, typesig)
    local self = Type{Base.unwrap_unionall(func)}
    local results = Method[]
    for each in alltypesigs(typesig)
        local args = Base.unwrap_unionall(each).parameters
        local tt = Base.rewrap_unionall(Base.rewrap_unionall(Tuple{self, args...}, each), func)
        append!(results, matched_methods(tt))
    end
    return results
end

"""
$(:SIGNATURES)

The methods matching the full call signature `tt`, a `Tuple` type of the callable's type and
the argument types.
"""
function matched_methods(tt)
    local world = ccall(:jl_get_world_counter, UInt, ())
    # Julia 1.0 gives each match as an `svec` holding the method third.
    return Method[m isa Core.SimpleVector ? m[3] : m.method for m in Base._methods_by_ftype(tt, -1, world)]
end

"""
$(:SIGNATURES)

Returns a `Vector` of the `Tuple` types contained in `sig`.
"""
function alltypesigs(sig)::Vector{Any}
    if sig == Union{}
        Any[]
    elseif isa(sig, Union)
        uniontypes(sig)
    elseif isa(sig, UnionAll)
        Any[Base.rewrap_unionall(usig, sig) for
            usig in uniontypes(Base.unwrap_unionall(sig))]
    else
        Any[sig]
    end
end

"""
$(:SIGNATURES)

A helper method for [`groupby`](@ref) that uses a pre-allocated `groups` `Dict`.
"""
function groupby!(f, groups, data)
    for each in data
        key, value = f(each)
        push!(get!(groups, key, []), value)
    end
    return sort!(collect(groups), by = first)
end

"""
$(:SIGNATURES)

Group `data` using function `f` where key type is specified by `K` and group type by `V`.

The function `f` takes a single argument, an element of `data`, and should return a 2-tuple
of `(computed_key, element)`. See the example below for details.

# Examples

```julia
groupby(Int, Vector{Int}, collect(1:10)) do num
    mod(num, 3), num
end
```
"""
groupby(f, K, V, data) = groupby!(f, Dict{K, V}(), data)

"""
$(:SIGNATURES)

Remove the depot prefix from a file `path` inside a depot, such as an installed package.
"""
function cleanpath(path::AbstractString)
    for depot in DEPOT_PATH
        pkgdir = joinpath(depot, "")
        startswith(path, pkgdir) && return first(split(path, pkgdir, keepempty=false))
    end
    return path
end

"""
$(:SIGNATURES)

The path of `file` relative to the root of the package that defines module `mod`, with `/`
separators. Falls back to [`cleanpath`](@ref) when `mod` is not part of a package or `file`
is outside it.
"""
function sourcepath(file::AbstractString, mod::Module)
    local entry = pathof(Base.moduleroot(mod))
    if entry !== nothing
        local root = joinpath(dirname(dirname(entry)), "")
        startswith(file, root) && return replace(relpath(file, root), '\\' => '/')
    end
    return cleanpath(file)
end

"""
$(:SIGNATURES)

Parse all docstrings defined within a module `mod`.
"""
function parsedocs(mod::Module)
    for (binding, multidoc) in Docs.meta(mod)
        for (typesig, docstr) in multidoc.docs
            Docs.parsedoc(docstr)
        end
    end
end

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
`nothing`.

# Examples

```julia
f(x; a = 1, b...) = x
sig = printmethod(Docs.Binding(Main, :f), f, first(methods(f)))
```
"""
function printmethod(buffer::IOBuffer, binding::Docs.Binding, func, method::Method; definition = nothing)
    local env = unionall_env(typevars(method.sig))
    typestring(t) = sprint(show, t; context = env)
    local names = argument_names(method, definition)
    local args = map(names, argument_types(method, length(names))) do arg, t
        arg == "_" && t !== Any ? "::$(typestring(t))" : arg
    end
    method.isva && (args[end] *= "...")
    args, kws = append_defaults(args, string.(keywords(func, method)), method, definition)
    local name = callable_name(binding, constructor_parameters(method), typestring)
    return printmethod_format(buffer, name, args, kws)
end

"""
$(:SIGNATURES)

The declared types of the first `n` positional arguments of `method`, with a vararg
argument's element type in place of its `Vararg`. A vararg with a count, such as
`xs::Vararg{Int,2}`, gets `Any`.
"""
function argument_types(method::Method, n::Integer)
    local types = Any[Base.unwrap_unionall(method.sig).parameters[2:end]...]
    method.isva || return types[1:n]
    local vararg = expanded_vararg(method) ? Any : Base.unwrapva(types[end])
    return Any[types[1:n-1]; vararg]
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

Drop the methods of `group` that Julia generated for positional default values, keeping
the method that takes every argument of `definition`.
"""
collapse_defaults(group, ::Nothing) = group
function collapse_defaults(group, definition::DefinitionArguments)
    local matching = filter(m -> matches_definition(m, definition), group)
    isempty(matching) && return group
    local longest = maximum(m -> length(arguments(m)), matching)
    return filter(group) do m
        !matches_definition(m, definition) || length(arguments(m)) == longest
    end
end

"""
$(:SIGNATURES)

Append `=default` to each formatted argument in `args` and keyword in `kws` that has a
default value in `definition`. Leaves both unchanged when `method` does not match
`definition`.
"""
function append_defaults(args, kws, method::Method, definition)
    matches_definition(method, definition) || return args, kws
    args = map(enumerate(args)) do (i, arg)
        _, default = definition.positional[i]
        default === nothing ? arg : "$arg=$default"
    end
    kws = map(kws) do kw
        default = get(definition.keywords, kw, nothing)
        default === nothing ? kw : "$kw=$default"
    end
    return args, kws
end

"""
$(:SIGNATURES)

Converts a method signature (or a union of several signatures) in a vector of (single)
signatures.

This is used for decoding the method signature that a docstring is paired with. In the case
when the docstring applies to multiple methods (e.g. when default positional argument values
are used and define multiple methods at once), they are combined together as union of `Tuple`
types.

```jldoctest; setup = :(using DocStringExtensions)
julia> DocStringExtensions.find_tuples(Tuple{String,Number,Int})
1-element Vector{DataType}:
 Tuple{String, Number, Int64}

julia> DocStringExtensions.find_tuples(Tuple{T} where T <: Integer)
1-element Vector{UnionAll}:
 Tuple{T} where T<:Integer

julia> s = Union{
         Tuple{Int64},
         Tuple{U},
         Tuple{T},
         Tuple{Int64,T},
         Tuple{Int64,T,U}
       } where U where T;

julia> DocStringExtensions.find_tuples(s)
5-element Vector{Type}:
 Tuple{Int64}
 Tuple{U} where U
 Tuple{T} where T
 Tuple{Int64, T} where T
 Tuple{Int64, T, U} where {T, U}
```
"""
function find_tuples(typesig)
    if typesig isa UnionAll
        return [UnionAll(typesig.var, x) for x in find_tuples(typesig.body)]
    elseif typesig isa Union
        return [typesig.a, find_tuples(typesig.b)...]
    else
        return [typesig,]
    end
end

"""
$(:TYPEDSIGNATURES)

Print a method signature to `buffer` with the argument types from `typesig`, followed by
the inferred return type when `print_return_types` is set. Type parameters keep their names
and are declared in a `where` clause after the arguments. Default values are left out
unless `definition` gives them.

`definition` is as for the untyped `printmethod`.

# Examples

```julia
f(x::Int; a = 1, b...) = x
sig = printmethod(Docs.Binding(Main, :f), f, first(methods(f)))
```
"""
function printmethod(buffer::IOBuffer, binding::Docs.Binding, func, method::Method, typesig; print_return_types=true, definition=nothing)
    # TODO: print qualified?
    local args = argument_names(method, definition)
    local kws = string.(keywords(func, method))

    local body = Base.unwrap_unionall(typesig)
    body isa DataType && body <: Tuple ||
        error("Expected `typeof($body)` to be `Tuple` or `UnionAll` but found `$(typeof(body))`")
    local params = constructor_parameters(method)
    # Innermost first: a type parameter used only in a later parameter's bound is still used.
    local used = Any[]
    for v in reverse(typevars(params === nothing ? typesig : method.sig))
        if Base.has_typevar(body, v) || params !== nothing && any(p -> Base.has_typevar(p, v), params) ||
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
    args, kws = append_defaults(args, kws, method, definition)

    rt = method_return_type(func, method, typesig)
    return_type_string = if (
        print_return_types &&
        length(rt) >= 1 &&
        rt[1] !== Nothing &&
        rt[1] !== Union{}
    )
        " -> $(rt[1])"
    else
        ""
    end

    return printmethod_format(
        buffer,
        callable_name(binding, params, typestring),
        args,
        kws;
        where_clause=where_clause(used),
        return_type=return_type_string
    )
end

printmethod(b, f, m) = String(take!(printmethod(IOBuffer(), b, f, m)))

where_clause(typevars) =
    isempty(typevars) ? "" :
    length(typevars) == 1 ? " where $(typevars[1])" :
    " where {$(join(typevars, ", "))}"

# The type parameters `t` declares, outermost first.
function typevars(t)
    local vars = TypeVar[]
    while t isa UnionAll
        push!(vars, t.var)
        t = t.body
    end
    return vars
end

# An `IOContext` in which `show` prints each of `typevars` by name.
unionall_env(typevars) = foldl((io, v) -> IOContext(io, :unionall_env => v), typevars; init = IOContext(devnull))

"""
$(:SIGNATURES)

The type parameters written in a constructor call, such as `[T]` for `Point{T}(x) where {T}`,
or `nothing` when `method` is not a constructor written with parameters. Julia stores such a
method under `Type{Point{T}}`, so `methods(Point)` leaves it out.
"""
function constructor_parameters(method::Method)
    local f = Base.unwrap_unionall(method.sig).parameters[1]
    istypeoftype(f) || return nothing
    local t = type_parameter(f)
    local body = Base.unwrap_unionall(t)
    body isa DataType || return nothing
    # `Point{T}` for a type with more parameters leaves the trailing ones free.
    local params = collect(body.parameters)
    local free = typevars(t)
    while !isempty(params) && last(params) in free
        pop!(params)
    end
    return isempty(params) ? nothing : params
end

# The name `method` is called by, with the parameters of a constructor written as `T{P}(...)`.
callable_name(binding, params, typestring) =
    params === nothing ? string(binding.var) : string(binding.var, "{", join(map(typestring, params), ", "), "}")

"""
$(:SIGNATURES)

The inferred return type of `method` for argument types `typesig`, as a vector holding one
type, or an empty vector when `method` does not match `typesig`. `Base.return_types` infers
every method that matches, so a more specific method whose signature overlaps `method` is
skipped by its position in `methods(func, typesig)`.
"""
function method_return_type(func, method::Method, typesig)
    local matching = collect(Base.invokelatest(methods, func, typesig))
    local idx = findfirst(m -> m === method, matching)
    idx === nothing && return []
    # Inference cannot run a generator on abstract argument types: Julia 1.0 throws and 1.10
    # hits a `BoundsError` in Base. Other versions infer `Any` for a generated method itself.
    any(hasgenerator, matching) && !isconcretetype(typesig) && return []
    return [Base.invokelatest(Base.return_types, func, typesig)[idx]]
end

# Julia 1.14 gives `Type{T}` the kind `TypeEq` in place of `DataType`.
@static if isdefined(Core, :TypeEq)
    istypeoftype(t) = Base.isType(t)
    type_parameter(t) = Base.type_parameter(t)
else
    istypeoftype(t) = t isa DataType && t.name === Type.body.name
    type_parameter(t) = t.parameters[1]
end

get_method_source(m::Method) = Base.uncompressed_ast(m)
nargs(m::Method) = m.nargs

"""
$(:SIGNATURES)

Whether `method` takes `xs::Vararg{T,n}`, which Julia writes into `method.sig` as `n`
arguments of type `T`.
"""
expanded_vararg(method::Method) =
    method.isva && !Base.isvarargtype(last(Base.unwrap_unionall(method.sig).parameters))

"""
$(:SIGNATURES)

The `n` of a `Vararg{T,n}` type, an `Int` or a method's type parameter, or `nothing` when
the vararg has no count.
"""
function vararg_length(t)
    local n = @static if VERSION > v"1.7-"
        isdefined(t, :N) ? t.N : nothing
    else
        # Before Julia 1.7, `xs::T...` is `Vararg{T,N} where N`, binding its own `N`.
        t isa UnionAll ? nothing : t.parameters[2]
    end
    return n isa Union{Int,TypeVar} ? n : nothing
end

"""
$(:SIGNATURES)

Returns the list of keywords for a particular method `m` of a function `func`.

# Examples

```julia
f(x; a = 1, b...) = x
kws = keywords(f, first(methods(f)))
```
"""
function keywords(func, m::Method)
    kwargs = @static if VERSION < v"1.4.0-DEV.215"
        table::Core.MethodTable = methods(func).mt
        # For some reason, the :kwsorter field is not always defined.
        # An undefined kwsorter seems to imply that there are no methods
        # in the MethodTable with keyword arguments.
        if Base.fieldindex(Core.MethodTable, :kwsorter, false) > 0 && !isdefined(table, :kwsorter)
            return Symbol[]
        end
        Base.kwarg_decl(m, typeof(table.kwsorter))
    else
        Base.kwarg_decl(m)
    end
    if !isa(kwargs, Vector) || isempty(kwargs)
        return Symbol[]
    end
    filter!(arg -> !occursin("#", string(arg)), kwargs)
    # Keywords *may* not be sorted correctly. We move the vararg one to the end.
    index = findfirst(arg -> endswith(string(arg), "..."), kwargs)
    if index != nothing
        kwargs[index], kwargs[end] = kwargs[end], kwargs[index]
    end
    return kwargs
end


"""
$(:SIGNATURES)

Returns the list of arguments for a particular method `m`.

# Examples

```julia
f(x; a = 1, b...) = x
args = arguments(first(methods(f)))
```
"""
function arguments(m::Method)
    local argnames = nothing
    if isdefined(m, :generator)
        # Generated function.
        argnames = m.generator.argnames
    else
        local template = get_method_source(m)
        if isdefined(template, :slotnames)
            argnames = template.slotnames
        end
    end
    if argnames !== nothing
        local args = map(argnames[1:nargs(m)]) do arg
            isself(arg) ? arg : isunnamed(arg) ? "_" : arg
        end
        return filter(!isself, args)
    end
    return Symbol[]
end

isself(arg) = arg === Symbol("#self#") || arg === Symbol("#ctor-self#")

# Unnamed and destructured arguments get compiler names such as `#unused#`, `#temp#`
# or an empty symbol.
isunnamed(arg) = isempty(string(arg)) || occursin('#', string(arg))

#
# Source URLs.
#
# Customised to handle URLs on travis since the directory is not a Git repo and we must
# instead rely on `TRAVIS_REPO_SLUG` to get the remote repo.
#

"""
$(:SIGNATURES)

Get the URL (file and line number) where a method `m` is defined.

Note that this is based on the implementation of `Base.url`, but handles URLs correctly
on TravisCI as well.
"""
function url(m::Method)
    if haskey(ENV, "TRAVIS_REPO_SLUG")
        repo = ENV["TRAVIS_REPO_SLUG"]

        commit = get(ENV, "TRAVIS_COMMIT", nothing)
        commit === nothing && return ""

        root = get(ENV, "TRAVIS_BUILD_DIR", nothing)
        root === nothing && return ""

        file = realpath(string(m.file))
        if startswith(file, root)
            filename = join(split(relpath(file, root), @static Sys.iswindows() ? '\\' : '/'), '/')
            base = "https://github.com/$repo/tree"
            return "$base/$commit/$filename#L$(m.line)"
        else
            return ""
        end
    else
        return Base.url(m)
    end
end

# This is compat to make sure that we have ismutabletype available pre-1.7.
# Implementation borrowed from JuliaLang/julia (MIT license).
# https://github.com/JuliaLang/julia/pull/39037
if isdefined(Base, :hasgenerator)
    const hasgenerator = Base.hasgenerator
else
    hasgenerator(m::Method) = isdefined(m, :generator)
end

if !isdefined(Base, :ismutabletype)
    function ismutabletype(@nospecialize(t::Type))
        t = Base.unwrap_unionall(t)
        return isa(t, DataType) && t.mutable
    end
end
