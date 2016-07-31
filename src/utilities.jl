
#
# Utilties.
#

"""
Given a callable object `f` and a signature `sig` collect, filter, and sort the
matching methods. All methods not defined within `mod` are discarded. Sorting
is based on file name and line number.

$(:methodlist)
"""
function filtermethods(f, sig, mod)
    local mt = sig == Union{} ? methods(f) : methods(f, sig)
    local results = Method[]
    for method in mt
        if getfield(method, :module)::Module == mod
            push!(results, method)
        end
    end
    local sorter = function(a, b)
        sa, sb = string(a.file), string(b.file)
        comp = sa < sb ? -1 : sa > sb ? 1 : 0
        comp == 0 ? a.line < b.line : comp < 0
    end
    return sort!(results, lt = sorter)
end

"""
Parse all docstrings defined within a module `mod`.

$(:methodlist)
"""
function parsedocs(mod::Module)
    for (binding, multidoc) in Docs.meta(mod)
        for (typesig, docstr) in multidoc.docs
            Docs.parsedoc(docstr)
        end
    end
end


#
# Bootstrap
#

"""
Within the package itself we would like to be able to use the abbreviations that have been
implemented. To do this we need to delay evaluation of the interpolated abbreviations until
they have all been defined. We use `Symbol`s in place of the actual constants, such as
`methodlist` which is written as `:methodlist` instead.

$(:methodlist)

!!! note

    The docstring for the module itself, defined at the start of the file, does not need to
    use `Symbol`s since with the way `@doc` works the module docstring gets inserted at the
    end of the module definition and so has all the definitions already defined.
"""
function bootstrap(mod::Module)
    λ = s -> isa(s, Symbol) ? getfield(mod, s) : s
    for (binding, multidoc) in Docs.meta(mod)
        for (typesig, docstr) in multidoc.docs
            docstr.text = Core.svec(map(λ, docstr.text)...)
        end
    end
end

