# [Custom abbreviations](@id custom-abbreviations)

```@meta
CurrentModule = DocStringExtensions
```

This guide writes an abbreviation of your own. An abbreviation is a value of a subtype of
[`Abbreviation`](@ref), and its [`format`](@ref) method writes the Markdown it expands to.
Neither name is exported, so qualify them or import them.

## Write the abbreviation

Define a subtype of `Abbreviation`, with fields for any options it takes. Then add a `format`
method that prints its Markdown to `buf`:

```jldoctest custom
julia> using DocStringExtensions

julia> struct Since <: DocStringExtensions.Abbreviation
           version::VersionNumber
       end

julia> DocStringExtensions.format(abbr::Since, buf, doc) =
           print(buf, "Available since version ", abbr.version, ".");

julia> """
       Compute the area of a square.
       $(Since(v"1.2.0"))
       """
       area(side) = side^2;

julia> @doc area
  Compute the area of a square. Available since version 1.2.0.
```

`format` runs the first time the docstring is shown, and Julia keeps the result for the rest
of the session. Anything `format` reads, such as methods defined after the docstring, must
exist by then. `doc` describes the docstring:
`doc.data[:binding]` is the documented binding, and `doc.data[:module]` is the module the
docstring is in.

## Read the documented expression

`format` sees the docstring, not the code it documents. To read the code, add a method of
[`interpolation`](@ref). Julia calls it as it defines the docstring, passing the documented
expression. The object it returns takes the place of the original in the docstring:

```jldoctest custom
julia> struct Documents <: DocStringExtensions.Abbreviation
           signature::Any
       end

julia> DocStringExtensions.interpolation(::Documents, expr) = Documents(expr.args[1]);

julia> DocStringExtensions.format(abbr::Documents, buf, doc) =
           print(buf, "Documents `", abbr.signature, "`.");

julia> """
       $(Documents(nothing))
       """
       perimeter(side) = 4side;

julia> @doc perimeter
  Documents perimeter(side).
```

`interpolation` runs for every object interpolated into a docstring, so define it only for
a type you own.
