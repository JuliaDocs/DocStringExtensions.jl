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
    found = Method[]
    for m in candidates
        m.module == modname || continue
        constructor = String(m.file) == definition.file ? m.line <= definition.last_line :
            definition.wrapped && generated_constructor(func, m)
        constructor && push!(found, m)
    end
    return insertion_sort!(found, (a, b) -> isless((length(arguments(a)), string(a.sig)), (length(arguments(b)), string(b.sig))))
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
    # A constructor written as `T{P}(...)` is a method of `Type{T{P}}`, and `(e::T)(x)` a
    # method of `T`'s instances. A list of `T`'s methods leaves out the callables.
    if func isa UnionAll
        append!(methods, constructor_methods(func, typesig == Union{} ? Tuple{Vararg{Any}} : typesig))
    end
    func isa Type && typesig != Union{} && exact && append!(methods, callable_methods(func, typesig))
    unique!(methods)
    # Group the methods from `modname` by file and line number.
    groups = Vector{Method}[]
    for m in methods
        m.module == modname || continue
        index = findfirst_group(groups, m)
        index === nothing ? push!(groups, Method[m]) : push!(groups[index], m)
    end

    # Filter out methods with non-matching signatures.
    typesigs = alltypesigs(typesig)
    results = Vector{Method}[]
    for group in groups
        if exact
            # Julia 1.12 and later can normalise the union of a definition's signatures
            # into a single type, such as `Union{Tuple{}, Tuple{Any, Vararg{Any}}} == Tuple`.
            # When no method matches a component, keep the group if its signatures together
            # equal `typesig`.
            matching = Method[]
            for m in group
                argsig(m) in typesigs && push!(matching, m)
            end
            if !isempty(matching) || !signatures_equal(group, typesig)
                group = matching
            end
        end
        isempty(group) || push!(results, group)
    end

    return insertion_sort!(results, (a, b) -> comparemethods(first(a), first(b)))
end

function findfirst_group(groups, m::Method)
    for i in eachindex(groups)
        first(groups[i]).file === m.file && first(groups[i]).line == m.line && return i
    end
    return nothing
end

# `Base.sort!` compiles a specialisation for each `lt`, while this runs interpreted with the
# rest of the package. The lists it sorts hold a few methods.
function insertion_sort!(xs, lt)
    for i in 2:length(xs)
        x = xs[i]
        j = i - 1
        while j >= 1 && lt(x, xs[j])
            xs[j + 1] = xs[j]
            j -= 1
        end
        xs[j + 1] = x
    end
    return xs
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
    nearest = nothing
    for group in groups
        m = first(group)
        String(m.file) == path && m.line >= line || continue
        (nearest === nothing || m.line < first(nearest).line) && (nearest = group)
    end
    return nearest === nothing ? groups : [nearest]
end

# The argument types of `m`, without the function's own type or a macro's hidden arguments.
function argsig(m::Method)
    params = tuple_parameters(Base.tuple_type_tail(m.sig))
    return Base.rewrap_unionall(Tuple{params[(1 + hidden_arguments(m)):end]...}, m.sig)::Type
end

# A macro method takes `__source__` and `__module__` before the arguments its caller writes.
hidden_arguments(m::Method) = ismacro(m) ? 2 : 0

# A function named `var"@f"` is not a macro, so the name alone does not decide.
function ismacro(m::Method)
    params = tuple_parameters(m.sig)
    return startswith(String(m.name), "@") && length(params) >= 3 &&
        params[2] === LineNumberNode && params[3] === Module
end
function ismacro(@nospecialize(f::Function))
    for m in Base.invokelatest(methods, f)::Base.MethodList
        ismacro(m) && return true
    end
    return false
end

# The argument types `f` is called with for those in `sig`, which a macro's docstring gives as
# its caller writes them.
call_signature(f, sig) =
    f isa Function && ismacro(f) ?
    Base.rewrap_unionall(Tuple{LineNumberNode, Module, tuple_parameters(sig)...}, sig) : sig

"""
$(:SIGNATURES)

Whether the methods of `group` together have the signature `typesig`. Subtyping cannot prove
that for a vararg tuple split across methods, such as `Tuple{Vararg{T}} where T` and the two
methods of `f(x::T = 1, xs::T...) where {T}`. So the types are compared at each number of
arguments, up to one past the most parameters any tuple declares. Larger counts only meet
varargs and compare the same.
"""
function signatures_equal(group, typesig)
    sigs = Any[]
    for m in group
        push!(sigs, argsig(m))
    end
    combined = Union{sigs...}
    longest = 0
    for t in sigs
        longest = max(longest, length(tuple_parameters(t)))
    end
    for t in alltypesigs(typesig)
        longest = max(longest, length(tuple_parameters(t)))
    end
    for n in 0:(longest + 1)
        typeintersect(typesig, NTuple{n, Any}) == typeintersect(combined, NTuple{n, Any}) || return false
    end
    return true
end

"""
$(:SIGNATURES)

The declared types of the first `n` positional arguments of `method`, with a vararg
argument's element type in place of its `Vararg`. A vararg with a count, such as
`xs::Vararg{Int,2}`, gets `Any`.
"""
function argument_types(method::Method, n::Integer)
    types = Any[tuple_parameters(argsig(method))...]
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
    body = Base.unwrap_unionall(t)
    body isa DataType || return nothing
    # A call through an alias writes the alias's parameters: `Mat{Int}(a)` for
    # `const Mat{T,B} = Arr{T,2,B}` is `Arr{Int,2,B}`.
    vars = typevars(func)
    params = match_parameters!(Any[vars...], vars, Base.unwrap_unionall(func), body)
    # `Point{T}` for a type with more parameters leaves the trailing ones free.
    free = typevars(t)
    while !isempty(params) && last(params) in free
        pop!(params)
    end
    return isempty(params) ? nothing : params
end

# Sets `params[i]` to the part of `t` in the place of `vars[i]` within `pattern`.
function match_parameters!(params, vars, pattern, t)
    if pattern isa TypeVar
        i = findfirst_identical(pattern, vars)
        i === nothing || (params[i] = t)
    elseif pattern isa DataType && t isa DataType && pattern.name === t.name
        for i in 1:min(length(pattern.parameters), length(t.parameters))
            match_parameters!(params, vars, pattern.parameters[i], t.parameters[i])
        end
    end
    return params
end

# The type of the callable a method belongs to. Julia 1.10 stores the default constructor of
# `Point{T}` under `Type{Point{T}} where T`, which declares its own type parameters.
self_type(method::Method) = tuple_parameters(method.sig)[1]

# The type of the instance that `method` is called on when it is a method of the instances of
# `func`, such as `E` for `(e::E)(σ)` or `E{NF}` for `(e::E{NF})(σ) where {NF}`, or `nothing`.
function instance_type(func, method::Method)
    func isa Type || return nothing
    self = self_type(method)
    return Base.rewrap_unionall(self, method.sig) <: func ? self : nothing
end

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
    matching = Method[]
    for m in Base.invokelatest(methods, func, typesig)::Base.MethodList
        push!(matching, m)
    end
    idx = findfirst_identical(method, matching)
    idx === nothing && return signature_return_type(method, typesig)
    # Inference cannot run a generator on abstract argument types: Julia 1.0 throws and 1.10
    # hits a `BoundsError` in Base. Other versions infer `Any` for a generated method itself.
    any_generated(matching) && !isconcretetype(typesig) && return []
    return Any[(Base.invokelatest(Base.return_types, func, typesig)::Vector{Any})[idx]]
end

# A callable `(e::T)(x)` or a constructor `T{P}(x)` is not a method of the documented `func`,
# so `methods(func)` misses it. Julia 1.6 and later infer it from its full signature.
function signature_return_type(method::Method, typesig)
    isdefined(Base, :code_typed_by_type) || return []
    args = Base.unwrap_unionall(typesig)
    args isa DataType || return []
    tt = typeintersect(method.sig, Base.rewrap_unionall(Tuple{Any, args.parameters...}, typesig))
    tt === Union{} && return []
    world = Base.get_world_counter()
    matching = Method[]
    for match in Base.invokelatest(Base._methods_by_ftype, tt, -1, world)
        push!(matching, match.method)
    end
    idx = findfirst_identical(method, matching)
    idx === nothing && return []
    any_generated(matching) && !isconcretetype(tt) && return []
    typed = Base.invokelatest(Base.code_typed_by_type, tt; optimize = false, world = world)
    return Any[last(typed[idx])]
end

function any_generated(methods)
    for m in methods
        hasgenerator(m) && return true
    end
    return false
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
            append!(results, Base.invokelatest(methods, f, call_signature(f, each))::Base.MethodList)
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
arguments match `typesig`. These are the constructors written as `T{P}(...)`. Julia stores
`D{T}(g)` for `struct D{T,MM}` under `Type{D{T}}`, with `MM` free inside the invariant `Type`,
so each leading run of `func`'s parameters is searched.
"""
function constructor_methods(func::UnionAll, typesig)
    vars = typevars(func)
    results = Method[]
    for n in 1:length(vars)
        append!(results, self_methods(t -> Base.rewrap_unionall(t, func), Type{func{vars[1:n]...}}, typesig))
    end
    return results
end

"""
$(:SIGNATURES)

The methods of the instances of the type `func` whose arguments match `typesig`. These are
the callables written as `(e::T)(...)`, which `methods(T)` leaves out.
"""
function callable_methods(func::Type, typesig)
    self = TypeVar(:Self, func)
    found = self_methods(t -> UnionAll(self, t), self, typesig)
    # Use a loop rather than e.g. filter() to avoid excessive compilation
    results = Method[]
    for m in found
        if instance_type(func, m) !== nothing
            push!(results, m)
        end
    end
    return results
end

# The methods of the callable type `self` whose arguments match `typesig`. `wrap` declares
# the type parameters that `self` uses.
function self_methods(wrap, self, typesig)
    results = Method[]
    for each in alltypesigs(typesig)
        tt = wrap(Base.rewrap_unionall(Tuple{self, tuple_parameters(each)...}, each))::Type
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
    found = Method[]
    # Julia 1.0 gives each match as an `svec` holding the method third.
    for m in Base._methods_by_ftype(tt, -1, world_counter())
        push!(found, m isa Core.SimpleVector ? m[3] : m.method)
    end
    return found
end

# Julia compiles any method holding a `ccall`, even in an interpreted module.
world_counter() = ccall(:jl_get_world_counter, UInt, ())

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
        sigs = Any[]
        for usig in uniontypes(Base.unwrap_unionall(sig))
            push!(sigs, Base.rewrap_unionall(usig, sig))
        end
        sigs
    else
        Any[sig]
    end
end

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
        # A callable of a type's instances sits in the table of its self type, not the
        # constructor table that `methods` returns for the type.
        table::Core.MethodTable = instance_type(func, m) === nothing ? methods(func).mt :
            Base.unwrap_unionall(self_type(m)).name.mt
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
    named = Symbol[]
    index = nothing
    for arg in kwargs
        occursin("#", string(arg)) && continue
        push!(named, arg)
        index === nothing && endswith(string(arg), "...") && (index = length(named))
    end
    # Keywords *may* not be sorted correctly. We move the vararg one to the end.
    if index != nothing
        named[index], named[end] = named[end], named[index]
    end
    return named
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
    # A keyword type parameter named as one in `vars` is that parameter.
    params = Any[]
    keyword_only = TypeVar[]
    for v in own
        i = findlast_named(vars, v.name)
        i === nothing && push!(keyword_only, v)
        push!(params, i === nothing ? v : vars[i])
    end
    sig = isempty(own) ? body.sig : body.sig{params...}
    names = get_method_source(body).slotnames
    sigtypes = tuple_parameters(sig)
    for i in 2:min(nargs(body), length(sigtypes))
        types[string(names[i])] = sigtypes[i]
    end
    return types, keyword_only
end

function findlast_named(vars, name::Symbol)
    for i in length(vars):-1:1
        vars[i].name === name && return i
    end
    return nothing
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
    names = String[]
    for arg in slot_names(m)[(2 + hidden_arguments(m)):end]
        push!(names, isunnamed(arg) ? "_" : string(arg))
    end
    return names
end

# The names of the argument slots of `m`, the callable itself first. Empty when `m` records none.
function slot_names(m::Method)
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
    argnames === nothing && return Symbol[]
    # The container type of `argnames` varies across Julia versions; its elements are `Symbol`s.
    return Symbol[argnames[1:nargs(m)]...]
end

# Unnamed and destructured arguments get compiler names such as `#unused#`, `#temp#`
# or an empty symbol.
isunnamed(arg) = isempty(string(arg)) || occursin('#', string(arg))
