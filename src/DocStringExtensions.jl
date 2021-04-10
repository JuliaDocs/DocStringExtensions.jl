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

Users are most welcome to suggest additional abbreviation ideas, or implement and submit
them themselves. Julia's strong support for program introspection makes this a reasonably
straight forward process.

Details of the currently available abbreviations can be viewed in their individual
docstrings listed below in the "Exports" section.

# Examples

In simple terms an abbreviation can be used by simply interpolating it into a suitable
docstring. For example:

```julia
using DocStringExtensions

\"""
A short summary of `func`...

\$(SIGNATURES)

where `x` and `y` should both be positive.

# Details

Some details about `func`...
\"""
func(x, y) = x + y
```

`\$(SIGNATURES)` will be replaced in the above docstring with

````markdown
# Signatures

```julia
func(x, y)
```
````

The resulting generated content can be viewed via Julia's `?` mode or, if `Documenter.jl` is
set up, the generated external documentation.

The advantage of using [`SIGNATURES`](@ref) (and other abbreviations) is that docstrings are
less likely to become out-of-sync with the surrounding code. Note though that references to
the argument names `x` and `y` that have been manually embedded within the docstring are, of
course, not updated automatically.

# Exports
$(EXPORTS)

# Imports
$(IMPORTS)

"""
module DocStringExtensions

# Imports.

import LibGit2

# Exports.

export @template, FIELDS, TYPEDFIELDS, EXPORTS, METHODLIST, IMPORTS
export SIGNATURES, TYPEDSIGNATURES, TYPEDEF, DOCSTRING, FUNCTIONNAME
export README, LICENSE

# Includes.

include("utilities.jl")
include("abbreviations.jl")
include("templates.jl")

#
# Bootstrap abbreviations.
#
# Within the package itself we would like to be able to use the abbreviations that have been
# implemented. To do this we need to delay evaluation of the interpolated abbreviations
# until they have all been defined. We use `Symbol`s in place of the actual constants, such
# as `METHODLIST` which is written as `:METHODLIST` instead.
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

__init__() = (hook!(template_hook); nothing)

end # module
