
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

