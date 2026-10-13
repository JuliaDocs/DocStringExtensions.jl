"""
$(:SIGNATURES)

The constructors of the type `func` that its struct definition creates, from the module
`modname`. In the definition's file, these are the methods defined no later than its last
line; a constructor cannot exist before its type. When a macro wraps the definition, they
include any constructor the macro may generate in another file.
"""
function struct_constructors(func, definition::StructDefinition, modname)
    candidates = getmethods(func, Union{})
    if func isa UnionAll
        candidates = unique([candidates; constructor_methods(func, Tuple{Vararg{Any}})])
    end
    found = filter(candidates) do m
        m.module == modname || return false
        String(m.file) == definition.file && return m.line <= definition.last_line
        return definition.wrapped && generated_constructor(func, m)
    end
    return sort!(found; by = m -> (length(arguments(m)), string(m.sig)))
end

# The keyword constructor `Base.@kwdef` and similar macros generate, and the positional one
# taking every field untyped. Julia 1.0 gives the `@kwdef` keyword constructor no location.
function generated_constructor(func, m::Method)
    fields = fieldnames(Base.unwrap_unionall(func))
    if isempty(arguments(m))
        return !isempty(fields) && Set(keywords(func, m)) == Set(fields)
    end
    return argsig(m) == Tuple{fill(Any, length(fields))...}
end

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
    methods = getmethods(func, typesig)
    # A docstring on a constructor written as `T{P}(...)` documents a method of `Type{T{P}}`.
    if func isa UnionAll && typesig != Union{}
        methods = unique([methods; constructor_methods(func, typesig)])
    end
    # Group methods by file and line number.
    groups = groupby(Tuple{Symbol, Int}, Vector{Method}, methods) do m
        (m.file, m.line), m
    end

    # Filter out methods from other modules and with non-matching signatures.
    typesigs = alltypesigs(typesig)
    results = Vector{Method}[]
    for (key, group) in groups
        filter!(m -> m.module == modname, group)
        if exact
            # Julia 1.12 and later can normalise the union of a definition's signatures
            # into a single type, such as `Union{Tuple{}, Tuple{Any, Vararg{Any}}} == Tuple`.
            # When no method matches a component, keep the group if its signatures together
            # equal `typesig`.
            matching = filter(m -> argsig(m) in typesigs, group)
            if !isempty(matching) || !signatures_equal(group, typesig)
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
    path = get(doc.data, :path, nothing)::Union{String, Nothing}
    line = get(doc.data, :linenumber, nothing)::Union{Int, Nothing}
    (path === nothing || line === nothing) && return groups
    after = filter(g -> String(first(g).file) == path && first(g).line >= line, groups)
    isempty(after) && return groups
    return [after[argmin(map(g -> first(g).line, after))]]
end

# The argument types of `m`, without the function's own type.
argsig(m::Method) = Base.rewrap_unionall(Base.tuple_type_tail(m.sig), m.sig)::Type

"""
$(:SIGNATURES)

Whether the methods of `group` together have the signature `typesig`. Subtyping cannot prove
that for a vararg tuple split across methods, such as `Tuple{Vararg{T}} where T` and the two
methods of `f(x::T = 1, xs::T...) where {T}`. So the types are compared at each number of
arguments, up to one past the most parameters any tuple declares. Larger counts only meet
varargs and compare the same.
"""
function signatures_equal(group, typesig)
    sigs = map(argsig, group)
    combined = Union{sigs...}
    longest = mapreduce(t -> length(tuple_parameters(t)), max, [alltypesigs(typesig); sigs]; init = 0)
    return all(0:(longest + 1)) do n
        typeintersect(typesig, NTuple{n, Any}) == typeintersect(combined, NTuple{n, Any})
    end
end

"""
$(:SIGNATURES)

The declared types of the first `n` positional arguments of `method`, with a vararg
argument's element type in place of its `Vararg`. A vararg with a count, such as
`xs::Vararg{Int,2}`, gets `Any`.
"""
function argument_types(method::Method, n::Integer)
    types = Any[tuple_parameters(method.sig)[2:end]...]
    method.isva || return types[1:n]
    vararg = expanded_vararg(method) ? Any : Base.unwrapva(types[end])
    return push!(types[1:(n - 1)], vararg)
end

# The type parameters `t` declares, outermost first.
function typevars(t)
    vars = TypeVar[]
    while t isa UnionAll
        push!(vars, t.var)
        t = t.body
    end
    return vars
end

"""
$(:SIGNATURES)

The type parameters written in a constructor call, such as `[T]` for `Point{T}(x) where {T}`,
or `nothing` when `method` is not a constructor of `func` written with parameters. Julia stores
such a method under `Type{Point{T}}`, so `methods(Point)` leaves it out.
"""
function constructor_parameters(func, method::Method)
    f = Base.unwrap_unionall(self_type(method))
    istypeoftype(f) || return nothing
    t = type_parameter(f)
    # A call through an alias, such as `Mat(a)` for `const Mat{T,B} = Arr{T,2,B}`, writes none.
    # Julia 1.13 finds `Point{T} == Point` for a free `T`, which `===` does not.
    t === func && return nothing
    body = Base.unwrap_unionall(t)
    body isa DataType || return nothing
    # `Point{T}` for a type with more parameters leaves the trailing ones free.
    params = collect(body.parameters)
    free = typevars(t)
    while !isempty(params) && last(params) in free
        pop!(params)
    end
    return isempty(params) ? nothing : params
end

# The type of the callable a method belongs to. Julia 1.10 stores the default constructor of
# `Point{T}` under `Type{Point{T}} where T`, which declares its own type parameters.
self_type(method::Method) = tuple_parameters(method.sig)[1]

# The parameters of the `Tuple` type `sig`, inside any `where`.
tuple_parameters(@nospecialize(sig)) = (Base.unwrap_unionall(sig)::DataType).parameters

# Julia 1.14 gives `Type{T}` the kind `TypeEq` in place of `DataType`.
@static if isdefined(Core, :TypeEq)
    istypeoftype(t) = Base.isType(t)
    type_parameter(t) = Base.type_parameter(t)
else
    istypeoftype(t) = t isa DataType && t.name === Type.body.name
    type_parameter(t) = t.parameters[1]
end

"""
$(:SIGNATURES)

Whether `method` takes `xs::Vararg{T,n}`, which Julia writes into `method.sig` as `n`
arguments of type `T`.
"""
expanded_vararg(method::Method) =
    method.isva && !Base.isvarargtype(last(tuple_parameters(method.sig)))

"""
$(:SIGNATURES)

The `n` of a `Vararg{T,n}` type, an `Int` or a method's type parameter, or `nothing` when
the vararg has no count.
"""
function vararg_length(t)
    n = @static if VERSION > v"1.7-"
        isdefined(t, :N) ? t.N : nothing
    else
        # Before Julia 1.7, `xs::T...` is `Vararg{T,N} where N`, binding its own `N`.
        t isa UnionAll ? nothing : t.parameters[2]
    end
    return n isa Union{Int, TypeVar} ? n : nothing
end

"""
$(:SIGNATURES)

The inferred return type of `method` for argument types `typesig`, as a vector holding one
type, or an empty vector when `method` does not match `typesig`. `Base.return_types` infers
every method that matches, so a more specific method whose signature overlaps `method` is
skipped by its position in `methods(func, typesig)`.
"""
function method_return_type(func, method::Method, typesig)
    matching = collect(Base.invokelatest(methods, func, typesig)::Base.MethodList)
    idx = findfirst(m -> m === method, matching)
    idx === nothing && return []
    # Inference cannot run a generator on abstract argument types: Julia 1.0 throws and 1.10
    # hits a `BoundsError` in Base. Other versions infer `Any` for a generated method itself.
    any(hasgenerator, matching) && !isconcretetype(typesig) && return []
    return Any[(Base.invokelatest(Base.return_types, func, typesig)::Vector{Any})[idx]]
end

if isdefined(Base, :hasgenerator)
    const hasgenerator = Base.hasgenerator
else
    hasgenerator(m::Method) = isdefined(m, :generator)
end

"""
$(:SIGNATURES)

Compare methods `a` and `b` by file and line number.
"""
function comparemethods(a::Method, b::Method)
    comp = a.file < b.file ? -1 : a.file > b.file ? 1 : 0
    return comp == 0 ? a.line < b.line : comp < 0
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
else
    uniontypes(T) = collect(T.types)
end

"""
$(:SIGNATURES)

A helper method for [`getmethods`](@ref) that collects methods in `results`.
"""
function getmethods!(results, f, sig)
    if sig == Union{}
        append!(results, Base.invokelatest(methods, f)::Base.MethodList)
    else
        # Each signature keeps its `where` bounds: Julia 1.14 matches no method against a
        # type variable left free with a bound.
        for each in alltypesigs(sig)
            append!(results, Base.invokelatest(methods, f, each)::Base.MethodList)
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
    self = Type{Base.unwrap_unionall(func)}
    results = Method[]
    for each in alltypesigs(typesig)
        args = tuple_parameters(each)
        tt = Base.rewrap_unionall(Base.rewrap_unionall(Tuple{self, args...}, each), func)::Type
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
    world = ccall(:jl_get_world_counter, UInt, ())
    # Julia 1.0 gives each match as an `svec` holding the method third.
    return Method[m isa Core.SimpleVector ? m[3] : m.method for m in Base._methods_by_ftype(tt, -1, world)]
end

"""
$(:SIGNATURES)

The `Tuple` types in `sig`, the signature a docstring is paired with. A docstring that
documents several methods at once, such as those that positional default values define, is
paired with the union of their signatures. Returns an empty vector for `Union{}`.

```jldoctest; setup = :(using DocStringExtensions)
julia> DocStringExtensions.alltypesigs(Tuple{String,Number,Int})
1-element Vector{Any}:
 Tuple{String, Number, Int64}

julia> DocStringExtensions.alltypesigs(Tuple{T} where T <: Integer)
1-element Vector{Any}:
 Tuple{T} where T<:Integer

julia> s = Union{
         Tuple{Int64},
         Tuple{U},
         Tuple{T},
         Tuple{Int64,T},
         Tuple{Int64,T,U}
       } where U where T;

julia> DocStringExtensions.alltypesigs(s)
5-element Vector{Any}:
 Tuple{Int64}
 Tuple{U} where U
 Tuple{T} where T
 Tuple{Int64, T} where T
 Tuple{Int64, T, U} where {T, U}
```
"""
function alltypesigs(sig)::Vector{Any}
    return if sig == Union{}
        Any[]
    elseif isa(sig, Union)
        uniontypes(sig)
    elseif isa(sig, UnionAll)
        Any[
            Base.rewrap_unionall(usig, sig) for
                usig in uniontypes(Base.unwrap_unionall(sig))
        ]
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

get_method_source(m::Method) = Base.uncompressed_ast(m)::Core.CodeInfo
nargs(m::Method) = m.nargs

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

The method holding the body of `method`, a method with keyword arguments, or `nothing` when
it cannot be found. Julia lowers `f(x; a::Int = 1)` to a method of `f` that fills in the
keyword defaults and ends by calling a hidden body method, `#f#1(a::Int, ::typeof(f), x)`.
"""
function keyword_body(method::Method)
    code = get_method_source(method).code
    length(code) >= 2 && Meta.isexpr(code[end - 1], :call) || return nothing
    call = code[end - 1]
    callee = ssa_value(code, call.args[1])
    # A positional vararg is splatted through `Core._apply`, or `Core._apply_iterate` from Julia 1.4.
    if callee == GlobalRef(Core, :_apply)
        callee = ssa_value(code, call.args[2])
    elseif callee == GlobalRef(Core, :_apply_iterate)
        callee = ssa_value(code, call.args[3])
    end
    callee isa GlobalRef || return nothing
    found = Base.invokelatest(methods, Base.invokelatest(getfield, callee.mod, callee.name))::Base.MethodList
    return length(found) == 1 ? first(found) : nothing
end

# Julia 1.12 and later load the callee into an SSA value before calling it.
ssa_value(code, @nospecialize(x)) = x isa Core.SSAValue ? code[x.id] : x

"""
$(:SIGNATURES)

The declared type of each keyword in `kws`, the keyword names of `method`, and the type
parameters that only keyword types use. A keyword type refers to the parameter in `vars` of
the same name, so it shares the signature's `where` clause.
"""
function keyword_types(method::Method, kws, vars)
    types = Dict{String, Any}()
    body = isempty(kws) ? nothing : keyword_body(method)
    body === nothing && return types, TypeVar[]
    own = typevars(body.sig)
    shared = Dict(v.name => v for v in vars)
    sig = isempty(own) ? body.sig : body.sig{[get(shared, v.name, v) for v in own]...}
    names = get_method_source(body).slotnames[2:nargs(body)]
    for (name, type) in zip(names, tuple_parameters(sig)[2:end])
        types[string(name)] = type
    end
    return types, filter(v -> !haskey(shared, v.name), own)
end


"""
$(:SIGNATURES)

The names of the positional arguments of method `m`, with `"_"` for an unnamed or
destructured argument.

# Examples

```julia
f(x; a = 1, b...) = x
args = arguments(first(methods(f)))
```
"""
function arguments(m::Method)
    argnames = nothing
    if isdefined(m, :generator)
        # Generated function.
        argnames = m.generator.argnames
    else
        template = get_method_source(m)
        if isdefined(template, :slotnames)
            argnames = template.slotnames
        end
    end
    argnames === nothing && return String[]
    # The container type of `argnames` varies across Julia versions; its elements are `Symbol`s.
    args = Symbol[argnames[1:nargs(m)]...]
    return String[isunnamed(arg) ? "_" : string(arg) for arg in args if !isself(arg)]
end

isself(arg) = arg === Symbol("#self#") || arg === Symbol("#ctor-self#")

# Unnamed and destructured arguments get compiler names such as `#unused#`, `#temp#`
# or an empty symbol.
isunnamed(arg) = isempty(string(arg)) || occursin('#', string(arg))
