__precompile__(true)

"""
*Extensions for the Julia docsystem.*

# Introduction

This package provides a collection of useful extensions for Julia's built-in docsystem.
These are features that are still regarded as "experimental" and not yet mature enough to be
considered for inclusion in `Base`, or that have sufficiently niche use cases that including
them with the default Julia installation is not seen as valuable enough at this time.

Currently `DocStringExtensions.jl` exports a collection of so-called "abbreviations", which
can be used to add useful automatically generated information to docstrings. These include
information such as:

  * simplified method signatures;
  * documentation for the individual fields of composite types;
  * import and export lists for modules;
  * and source-linked lists of methods applicable to a particular docstring.

Details of the currently available abbreviations can be viewed in their individual
docstrings listed below in the "Exports" section.

# Examples

In simple terms an abbreviation can be used by simply interpolating it into a suitable
docstring. For example:

```julia
\"""
A short summary of `func`...

\$signatures

where `x` and `y` should both be positive.

# Details

Some details about `func`...
\"""
func(x, y) = x + y
```

The resulting generated content can then be viewed via Julia's `?` mode or, if
`Documenter.jl` is set up, the generated external documentation.

The advantage of using [`signatures`](@ref) (and other abbreviations) is that docstrings are
less likely to become out-of-sync with the surrounding code. Note though that references to
the argument names `x` and `y` that have been manually embedded within the docstring are, of
course, not updated automatically.

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

export fields, exports, methodlist, imports, signatures


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
