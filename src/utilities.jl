
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
    local groups = groupby(Tuple{Symbol, Int}, Vector{Method}, methods) do m
        (m.file, m.line), m
    end

    # Filter out methods from other modules and with non-matching signatures.
    local typesigs = alltypesigs(typesig)
    local results = Vector{Method}[]
    for (key, group) in groups
        filter!(group) do m
            local ismod = m.module == modname
            exact ? (ismod && Base.rewrap_unionall(Base.tuple_type_tail(m.sig), m.sig) in typesigs) : ismod
        end
        isempty(group) || push!(results, group)
    end

    # Sort the groups by file and line.
    sort!(results, lt = comparemethods, by = first)

    return results
end

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
        append!(results, methods(f))
    elseif isa(sig, Union)
        for each in uniontypes(sig)
            getmethods!(results, f, each)
        end
    elseif isa(sig, UnionAll)
        getmethods!(results, f, Base.unwrap_unionall(sig))
    else
        append!(results, methods(f, sig))
    end
    return results
end

"""
$(:SIGNATURES)

Collect and return all methods of function `f` matching signature `sig`.

This is similar to `methods(f, sig)`, but handles type signatures found in `DocStr` objects
more consistently that `methods`.
"""
getmethods(f, sig) = unique(getmethods!(Method[], f, sig))

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

Remove the `Pkg.dir` part of a file `path` if it exists.
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

function printmethod_format(buffer::IOBuffer, binding::String, args::Vector{String}, kws::Vector{String}; return_type = "")

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
    print(buffer, return_type)
    return buffer
end

"""
$(:SIGNATURES)

Print a simplified representation of a method signature to `buffer`. Some of these
simplifications include:

  * no `TypeVar`s;
  * no types;
  * no keyword default values;
  * `_` printed where `#unused#` arguments are found.

# Examples

```julia
f(x; a = 1, b...) = x
sig = printmethod(Docs.Binding(Main, :f), f, first(methods(f)))
```
"""
printmethod(buffer::IOBuffer, binding::Docs.Binding, func, method::Method) =
    printmethod_format(buffer, string(binding.var),
        string.(arguments(method)),
        string.(keywords(func, method)))

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
1-element Array{DataType,1}:
 Tuple{String,Number,Int64}

julia> DocStringExtensions.find_tuples(Tuple{T} where T <: Integer)
1-element Array{DataType,1}:
 Tuple{T<:Integer}

julia> s = Union{
         Tuple{Int64},
         Tuple{U},
         Tuple{T},
         Tuple{Int64,T},
         Tuple{Int64,T,U}
       } where U where T;

julia> DocStringExtensions.find_tuples(s)
5-element Array{DataType,1}:
 Tuple{Int64}
 Tuple{U}
 Tuple{T}
 Tuple{Int64,T}
 Tuple{Int64,T,U}
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

Print a simplified representation of a method signature to `buffer`. Some of these
simplifications include:

  * no `TypeVar`s;
  * no types;
  * no keyword default values;

# Examples

```julia
f(x::Int; a = 1, b...) = x
sig = printmethod(Docs.Binding(Main, :f), f, first(methods(f)))
```
"""
function printmethod(buffer::IOBuffer, binding::Docs.Binding, func, method::Method, typesig)
    # TODO: print qualified?
    local args = string.(arguments(method))
    local kws = string.(keywords(func, method))

    # find inner tuple type
    function find_inner_tuple_type(t)
        # t is always either a UnionAll which represents a generic type or a Tuple where each parameter is the argument
        if t isa DataType && t <: Tuple
            t
        elseif t isa UnionAll
            find_inner_tuple_type(t.body)
        else
            error("Expected `typeof($t)` to be `Tuple` or `UnionAll` but found `$typeof(t)`")
        end
    end

    function get_typesig(t::Union, org::Union)
        if t.a isa TypeVar
            UnionAll(t.a, get_typesig(t.b, org))
        elseif t.b isa TypeVar
            UnionAll(t.b, t)
        else
            t
        end
    end

    function get_typesig(typ::TypeVar, org)
        UnionAll(typ, org)
    end

    function get_typesig(typ, org)
        typ
    end

    # if `typesig` is an UnionAll, it may be
    # e.g. Tuple{Vector{T}} where T<:Number
    # or   Tuple{String, T, T} where T<:Number
    # or   Tuple{Type{T}, String, Union{Nothing, Function}} where T<:Number
    # in the other case, it's usually something like Tuple{Vector{Int}}.
    argtypes = typesig isa UnionAll ?
            [get_typesig(t, t) for t in find_inner_tuple_type(typesig).types] :
            collect(typesig.types)

    args = map(args, argtypes) do arg,t
        type = ""
        suffix = ""
        if isvarargtype(t)
            t = vararg_eltype(t)
            suffix = "..."
        end
        if t!==Any
            type = "::$t"
        end

        "$arg$type$suffix"
    end

    rt = Base.return_types(func, typesig)

    return printmethod_format(buffer, string(binding.var), args, string.(kws);
        return_type =
            length(rt) >= 1 && rt[1] !== Nothing && rt[1] !== Union{} ?
            " -> $(rt[1])" : "")
end

printmethod(b, f, m) = String(take!(printmethod(IOBuffer(), b, f, m)))

get_method_source(m::Method) = Base.uncompressed_ast(m)
nargs(m::Method) = m.nargs

function isvarargtype(t)
    @static if VERSION > v"1.7-"
        t isa Core.TypeofVararg
    elseif VERSION > v"1.5-"
        t isa Type && t <: Vararg
    else
        # don't special print Vararg
        # below 1.5
        false
    end
end

function vararg_eltype(t)
    @static if VERSION > v"1.7-"
        return t.T
    elseif VERSION > v"1.5-"
        if t isa DataType
            return t.parameters[1]
        elseif t isa UnionAll
            return t.body.parameters[1]
        else
            # don't know how to handle
            # just return Any
            return Any
        end
    else
        error("cannot handle Vararg below 1.5")
    end
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
            arg === Symbol("#unused#") ? "_" : arg
        end
        return filter(arg -> arg !== Symbol("#self#") && arg !== Symbol("#ctor-self#"), args)
    end
    return Symbol[]
end

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
if !isdefined(Base, :ismutabletype)
    function ismutabletype(@nospecialize(t::Type))
        t = Base.unwrap_unionall(t)
        return isa(t, DataType) && t.mutable
    end
end
