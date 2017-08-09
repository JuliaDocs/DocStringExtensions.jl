
#
# Utilities.
#

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
    local methods = Set{Method}(getmethods(func, typesig))
    local groups = groupby(Tuple{Symbol, Int}, Vector{Method}, methods) do m
        (m.file, m.line), m
    end

    # Filter out methods from other modules and with non-matching signatures.
    local typesigs = alltypesigs(typesig)
    local results = Vector{Method}[]
    for (key, group) in groups
        filter!(group) do m
            local ismod = m.module == modname
            exact ? (ismod && Base.tuple_type_tail(m.sig) in typesigs) : ismod
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
            append!(results, getmethods(f, each))
        end
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
getmethods(f, sig) = getmethods!(Method[], f, sig)


"""
$(:SIGNATURES)

Is the type `t` a `bitstype`?
"""
isbitstype(t::ANY) = isleaftype(t) && sizeof(t) > 0 && isbits(t)

"""
$(:SIGNATURES)

Is the type `t` an `abstract` type?
"""
isabstracttype(t::ANY) = isa(t, DataType) && getfield(t, :abstract)


"""
$(:SIGNATURES)

Returns a `Vector` of the `Tuple` types contained in `sig`.
"""
alltypesigs(sig) = sig == Union{} ? Any[] : isa(sig, Union) ? uniontypes(sig) : Any[sig]

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
    local pkgdir = joinpath(Pkg.dir(), "")
    return startswith(path, pkgdir) ? first(split(path, pkgdir; keep = false)) : path
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

Print a simplified representation of a method signature to `buffer`. Some of these
simplifications include:

  * no `TypeVar`s;
  * no types;
  * no keyword default values;
  * `?` printed where `#unused#` arguments are found.

# Examples

```julia
f(x; a = 1, b...) = x
sig = printmethod(Docs.Binding(Main, :f), f, first(methods(f)))
```
"""
function printmethod(buffer::IOBuffer, binding::Docs.Binding, func, method::Method)
    # TODO: print qualified?
    print(buffer, binding.var)
    print(buffer, "(")
    join(buffer, arguments(method), ", ")
    local kws = keywords(func, method)
    if !isempty(kws)
        print(buffer, "; ")
        join(buffer, kws, ", ")
    end
    print(buffer, ")")
    return buffer
end

printmethod(b, f, m) = String(take!(printmethod(IOBuffer(), b, f, m)))

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
    local table = methods(func).mt
    if isdefined(table, :kwsorter)
        local kwsorter = table.kwsorter
        local signature = Base.tuple_type_cons(Vector{Any}, m.sig)
        if method_exists(kwsorter, signature)
            local method = which(kwsorter, signature)
            local template = get_method_source(method)
            # `.slotnames` is a `Vector{Any}`. Convert it to the right type.
            local args = map(Symbol, template.slotnames[(nargs(method) + 1):end])
            # Only return the usable symbols, not ones that aren't identifiers.
            filter!(arg -> !contains(string(arg), "#"), args)
            # Keywords *may* not be sorted correctly. We move the vararg one to the end.
            local index = findfirst(arg -> endswith(string(arg), "..."), args)
            if index > 0
                args[index], args[end] = args[end], args[index]
            end
            return args
        end
    end
    return Symbol[]
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
    local template = get_method_source(m)
    if isdefined(template, :slotnames)
        local args = map(template.slotnames[1:nargs(m)]) do arg
            arg === Symbol("#unused#") ? "?" : arg
        end
        return filter(arg -> arg !== Symbol("#self#"), args)
    end
    return Symbol[]
end

#
# Source URLs.
#
# Based on code from https://github.com/JuliaLang/julia/blob/master/base/methodshow.jl.
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
url(m::Method) = url(m.module, string(m.file), m.line)

function url(mod::Module, file::AbstractString, line::Integer)
    file = Compat.Sys.iswindows() ? replace(file, '\\', '/') : file
    if Base.inbase(mod) && !isabspath(file)
        local base = "https://github.com/JuliaLang/julia/tree"
        if isempty(Base.GIT_VERSION_INFO.commit)
            return "$base/v$VERSION/base/$file#L$line"
        else
            local commit = Base.GIT_VERSION_INFO.commit
            return "$base/$commit/base/$file#L$line"
        end
    else
        if isfile(file)
            local d = dirname(file)
            return LibGit2.with(LibGit2.GitRepoExt(d)) do repo
                LibGit2.with(LibGit2.GitConfig(repo)) do cfg
                    local u = LibGit2.get(cfg, "remote.origin.url", "")
                    local m = match(LibGit2.GITHUB_REGEX, u)
                    u = m === nothing ? get(ENV, "TRAVIS_REPO_SLUG", "") : m.captures[1]
                    local commit = string(LibGit2.head_oid(repo))
                    local root = LibGit2.path(repo)
                    if startswith(file, root) || startswith(realpath(file), root)
                        local base = "https://github.com/$u/tree"
                        local filename = file[(length(root) + 1):end]
                        return "$base/$commit/$filename#L$line"
                    else
                        return ""
                    end
                end
            end
        else
            return ""
        end
    end
end

