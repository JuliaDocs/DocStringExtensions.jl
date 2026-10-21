"""
*Extensions for the Julia docsystem.*

DocStringExtensions generates parts of a docstring from the code it documents, so the
docstring stays in step with the code. You interpolate an abbreviation into a docstring,
and it expands to Markdown when the docstring is first shown, in the REPL's `?` mode or in
Documenter.jl. Abbreviations cover method signatures and method lists, struct fields and
subtypes, enum instances, and module exports. [`@template`](@ref) adds abbreviations to every docstring of
a given kind in a module.

# Examples

When the docstring is shown, `\$(SIGNATURES)` is replaced by the signature:

```jldoctest
julia> using DocStringExtensions

julia> \"""
       A short summary of `func`.
       \$(SIGNATURES)
       where `x` and `y` should both be positive.
       \"""
       func(x, y) = x + y;

julia> @doc func
  A short summary of func.

  func(x, y)

  where x and y should both be positive.
```

Argument names written into the text by hand, such as `x` and `y` above, are not updated.

# Exports
$(EXPORTS)
"""
module DocStringExtensions

# A docstring renders once per session, so interpreting the package costs less than compiling it.
@static if VERSION >= v"1.6"
    Base.Experimental.@compiler_options compile = min
end

# Exports.

export @template, FIELDS, TYPEDFIELDS, EXPORTS, PUBLIC, METHODLIST, TYPEDMETHODLIST, IMPORTS
export SIGNATURES, TYPEDSIGNATURES, TYPEDEF, INSTANCES, SUBTYPES, DOCSTRING, FUNCTIONNAME, BODY
export README, LICENSE, NOTEMPLATE

# `public` is a syntax error before Julia 1.11.
VERSION >= v"1.11" && eval(
    Meta.parse(
        "public Abbreviation, format, interpolation, MethodSignatures, TypedMethodSignatures, " *
            "MethodList, TypedMethodList, TypeFields, TemplateOverride"
    )
)

# Includes. Each file loads after the files defining the types its fields and signatures name.

include("interface.jl")
include("definitions.jl")
include("methods.jl")
include("settings.jl")
include("type_text.jl")
include("printmethod.jl")
include("abbreviations/fields.jl")
include("abbreviations/module_names.jl")
include("abbreviations/imports.jl")
include("abbreviations/methodlist.jl")
include("abbreviations/signatures.jl")
include("abbreviations/functionname.jl")
include("abbreviations/body.jl")
include("abbreviations/typedef.jl")
include("abbreviations/instances.jl")
include("abbreviations/subtypes.jl")
include("abbreviations/package_files.jl")
include("abbreviations/docstring.jl")
include("abbreviations/notemplate.jl")
include("templates.jl")
include("hook.jl")

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

__init__() = (setter!(template_hook); nothing)

end # module
