"""
$(:SIGNATURES)

The constructors of the type `func` that its struct definition creates, from the module
`modname`. In the definition's file, these are the methods defined no later than its last
line; a constructor cannot exist before its type. When a macro wraps the definition, they
include any constructor the macro may generate in another file.
"""
function struct_constructors(func, definition::StructDefinition, modname)
    local candidates = getmethods(func, Union{})
    if func isa UnionAll
        candidates = unique([candidates; constructor_methods(func, Tuple{Vararg{Any}})])
    end
    local found = filter(candidates) do m
        m.module == modname || return false
        String(m.file) == definition.file && return m.line <= definition.last_line
        return definition.wrapped && generated_constructor(func, m)
    end
    return sort!(found; by = m -> (length(arguments(m)), string(m.sig)))
end

# The keyword constructor `Base.@kwdef` and similar macros generate, and the positional one
# taking every field untyped. Julia 1.0 gives the `@kwdef` keyword constructor no location.
function generated_constructor(func, m::Method)
    local fields = fieldnames(Base.unwrap_unionall(func))
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

get_method_source(m::Method) = Base.uncompressed_ast(m)
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
    local code = get_method_source(method).code
    length(code) >= 2 && Meta.isexpr(code[end-1], :call) || return nothing
    local call = code[end-1]
    local callee = ssa_value(code, call.args[1])
    # A positional vararg is splatted through `Core._apply`, or `Core._apply_iterate` from Julia 1.4.
    if callee == GlobalRef(Core, :_apply)
        callee = ssa_value(code, call.args[2])
    elseif callee == GlobalRef(Core, :_apply_iterate)
        callee = ssa_value(code, call.args[3])
    end
    callee isa GlobalRef || return nothing
    local found = Base.invokelatest(methods, Base.invokelatest(getfield, callee.mod, callee.name))
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
    local types = Dict{String,Any}()
    local body = isempty(kws) ? nothing : keyword_body(method)
    body === nothing && return types, TypeVar[]
    local own = typevars(body.sig)
    local shared = Dict(v.name => v for v in vars)
    local sig = isempty(own) ? body.sig : body.sig{[get(shared, v.name, v) for v in own]...}
    local names = get_method_source(body).slotnames[2:nargs(body)]
    for (name, type) in zip(names, sig.parameters[2:end])
        types[string(name)] = type
    end
    return types, filter(v -> !haskey(shared, v.name), own)
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
