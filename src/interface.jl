"""
The supertype of every abbreviation. An `Abbreviation` interpolated into a docstring expands
through its [`format`](@ref) method the first time the docstring is shown, and Julia keeps
the result for the rest of the session. To write your own, subtype it and add a `format`
method.
"""
abstract type Abbreviation end

"""
$(:SIGNATURES)

Expand the [`Abbreviation`](@ref) `abbr` in the context of the `DocStr` `doc` and write
the resulting markdown-formatted text to the `IOBuffer` `buf`. `doc.data[:binding]` is the
documented `Docs.Binding`, and `doc.data[:module]` the module the docstring is in.
"""
format(abbr, buf, doc) = error("`format` not implemented for `$(typeof(abbr))`.")

# Only extend `formatdoc` once with our abstract type. Within the package use a different
# `format` function instead to keep things decoupled from `Base` as much as possible.
Docs.formatdoc(buf::IOBuffer, doc::Docs.DocStr, part::Abbreviation) = format(part, buf, doc)

# `doc.data` holds `Any`, so these assert the types `Docs` stores.
doc_binding(doc::Docs.DocStr) = doc.data[:binding]::Docs.Binding
doc_module(doc::Docs.DocStr) = doc.data[:module]::Module

"""
$(:SIGNATURES)

The object a docstring holds in place of the interpolated `object`, given the expression
`expr` that the docstring documents. Julia calls it as it defines the docstring, so a method
for an [`Abbreviation`](@ref) can read code that [`format`](@ref) never sees. The fallback
returns `object`. It runs for every object interpolated into a docstring, so add methods
only for types you own.
"""
interpolation(@nospecialize(object), @nospecialize(expr)) = object

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
    return
end
