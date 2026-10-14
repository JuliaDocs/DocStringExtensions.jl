"""
The type for [`METHODLIST`](@ref) abbreviations.

$(:FIELDS)
"""
struct MethodList <: Abbreviation
    returns::Bool
end

MethodList(; returns::Bool = false) = MethodList(returns)

"""
An [`Abbreviation`](@ref) that lists the methods of the documented function or type that
are defined in the current module. Each method shows its signature and a link to the line
that defines it.

# Examples

Methods defined in the REPL have no file to link to, so the list below shows only their
signatures.

```jldoctest
julia> \"""
       Scale `x` by a factor.
       \$(METHODLIST)
       \"""
       function scale end;

julia> scale(x) = 2x;

julia> scale(x, factor) = factor * x;

julia> @doc scale
  Scale x by a factor.

  scale(x, factor)
  scale(x)
```

!!! tip "Showing the Return Type"
    To follow each signature with its inferred return type, use
    `\$(DocStringExtensions.MethodList(returns = true))`.
"""
const METHODLIST = MethodList()

"""
The type for [`TYPEDMETHODLIST`](@ref) abbreviations.

$(:FIELDS)
"""
struct TypedMethodList <: Abbreviation
    returns::Bool
end

TypedMethodList(; returns::Bool = true) = TypedMethodList(returns)

"""
An [`Abbreviation`](@ref) that lists methods like [`METHODLIST`](@ref), with argument types
and the inferred return type in each signature.

# Examples

```jldoctest
julia> \"""
       Scale `x` by a factor.
       \$(TYPEDMETHODLIST)
       \"""
       function scale end;

julia> scale(x::Int) = 2x;

julia> scale(x::Float64, factor::Float64) = factor * x;

julia> @doc scale
  Scale x by a factor.

  scale(x::Float64, factor::Float64) -> Float64
  scale(x::Int64) -> Int64
```

!!! tip "Disabling the Return Type"
    A return type inferred as `Any` is left out. To leave out every return type, use
    `\$(DocStringExtensions.TypedMethodList(returns = false))`.
"""
const TYPEDMETHODLIST = TypedMethodList()

printlisted(buf, abbr::MethodList, binding, func, method) =
    printmethod(buf, binding, func, method; returns = abbr.returns)
printlisted(buf, abbr::TypedMethodList, binding, func, method) =
    printmethod(buf, binding, func, method, argsig(method); returns = abbr.returns)

function format(abbr::Union{MethodList, TypedMethodList}, buf, doc)
    binding = doc_binding(doc)
    typesig = doc.data[:typesig]
    modname = doc_module(doc)
    func = Base.invokelatest(Docs.resolve, binding)
    groups = methodgroups(func, typesig, modname; exact = false)
    if !isempty(groups)
        println(buf)
        for group in groups
            println(buf, "```julia")
            for method in group
                printlisted(buf, abbr, binding, func, method)
                println(buf)
            end
            println(buf, "```\n")
            method = first(group)
            path = sourcepath(string(method.file), modname)
            URL = url(method)
            isempty(URL) || println(buf, "defined at [`$path:$(method.line)`]($URL).")
            println(buf)
        end
        println(buf)
    end
    return nothing
end

"""
$(:SIGNATURES)

Remove the depot prefix from a file `path` inside a depot, such as an installed package.
"""
function cleanpath(path::AbstractString)
    for depot in DEPOT_PATH
        pkgdir = joinpath(depot, "")
        startswith(path, pkgdir) && return first(split(path, pkgdir, keepempty = false))
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
    entry = pathof(Base.moduleroot(mod))
    if entry !== nothing
        root = joinpath(dirname(dirname(entry)), "")
        startswith(file, root) && return replace(relpath(file, root), '\\' => '/')
    end
    return cleanpath(file)
end

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
