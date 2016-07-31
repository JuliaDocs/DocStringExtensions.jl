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


# Bootstrap abbreviations.

bootstrap(DocStringExtensions)

end # module
