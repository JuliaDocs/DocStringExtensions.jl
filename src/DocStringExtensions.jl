__precompile__(true)

"""
Provides extensions to the Julia docsystem.

$(exports)

$(imports)

!!! warning

    This package is currently in early development and should not be used not be used for
    anything other than entertainment at the moment.

    Both the public interface and private internals are likely the change without notice.

"""
module DocStringExtensions

# Imports.

using Compat


# Exports.

export fields, exports, methodlist, imports


# Includes.

include("utilities.jl")
include("abbreviations.jl")


#
# Bootstrap abbreviations.
#
# Within the package itself we would like to be able to use the abbreviations that have been
# implemented. To do this we need to delay evaluation of the interpolated abbreviations
# until they have all been defined. We use `Symbol`s in place of the actual constants, such
# as `methodlist` which is written as `:methodlist` instead.
#
# The docstring for the module itself, defined at the start of the file, does not need to
# use `Symbol`s since with the way `@doc` works the module docstring gets inserted at the
# end of the module definition and so has all the definitions already defined.
#
let λ = s -> isa(s, Symbol) ? getfield(DocStringExtensions, s) : s
    for (binding, multidoc) in Docs.meta(DocStringExtensions)
        for (typesig, docstr) in multidoc.docs
            docstr.text = Core.svec(map(λ, docstr.text)...)
        end
    end
end

end # module
