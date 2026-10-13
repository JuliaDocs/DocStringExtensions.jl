"""
Abbreviation objects are used to automatically generate context-dependent markdown content
within documentation strings. Objects of this type interpolated into docstrings will be
expanded automatically before parsing the text to markdown.

$(:FIELDS)
"""
abstract type Abbreviation end

"""
$(:SIGNATURES)

Expand the [`Abbreviation`](@ref) `abbr` in the context of the `DocStr` `doc` and write
the resulting markdown-formatted text to the `IOBuffer` `buf`.
"""
format(abbr, buf, doc) = error("`format` not implemented for `$(typeof(abbr))`.")

# Only extend `formatdoc` once with our abstract type. Within the package use a different
# `format` function instead to keep things decoupled from `Base` as much as possible.
Docs.formatdoc(buf::IOBuffer, doc::Docs.DocStr, part::Abbreviation) = format(part, buf, doc)

"""
    interpolation(object::T, captured::Expr) -> new_object

Interface method for hooking into interpolation within docstrings to change
the behaviour of the interpolation. `object` is the interpolated object within a
docstring and `captured` is the raw expression that is documented by the docstring
in which the interpolated `object` has been included.

To define custom behaviour for your own `object` types implement a method of
`interpolation(::T, captured)` for type `T` and return a `new_object` to
be interpolated into the final docstring. Note that you must own the definition
of type `T`. `new_object` does not need to be of type `T`.
"""
interpolation(@nospecialize(object), @nospecialize(_)) = object

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
