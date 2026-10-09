module TemplateTests

using DocStringExtensions

@template DEFAULT =
    """
    (DEFAULT)

    $(DOCSTRING)
    """

@template TYPES =
    """
    (TYPES)

    $(TYPEDEF)

    $(DOCSTRING)
    """

@template (METHODS, MACROS) =
    """
    (METHODS, MACROS)

    $(SIGNATURES)

    $(DOCSTRING)

    $(METHODLIST)
    """

"constant `K`"
const K = 1

"mutable struct `T`"
mutable struct T end

"mutable struct `ISSUE_115{S}`"
mutable struct ISSUE_115{S} end

"`@kwdef` struct `S`"
Base.@kwdef struct S end

"method `f`"
f(x) = x

"method `g`"
g(::Type{T}) where {T} = T # Issue 32

"inlined method `h`"
@inline h(x) = x

"macro `@m`"
macro m(x) end

@template MODULES =
    """
    (MODULES)

    $(DOCSTRING)
    """

"module `Sub`"
module Sub end

if true
    @doc "method `conditional`" conditional(x) = x
end

for name in (:generated_1, :generated_2)
    @eval begin
        "method `$($(QuoteNode(name)))`"
        $name(x) = x
    end
end

using Markdown
@doc md"markdown method `markdown`" markdown(x) = x

const pair_1 = 1
const pair_2 = 2

"constants `pair_1` and `pair_2`"
pair_1, pair_2

"function `declared`"
function declared end

"method `interpolating` with $(SIGNATURES) inside"
interpolating(x) = x

"struct `KeywordConstructor`"
struct KeywordConstructor
    x::Int
    KeywordConstructor(; x = 1) = new(x)
end

"struct `ParametricKeywordConstructor`"
struct ParametricKeywordConstructor{T}
    x::T
    ParametricKeywordConstructor{T}(x; y = 1) where {T} = new{T}(x)
end

const DOC_VALUES = (
    method = (@doc "method `valued`" valued(x) = x),
    type = (@doc "struct `Valued`" struct Valued end),
    constant = (@doc "constant `VALUED`" const VALUED = 1),
)
const VALUED_A = 1
const VALUED_B = 2

module Untemplated
    const DOC_VALUES = (
        method = (@doc "method `valued`" valued(x) = x),
        type = (@doc "struct `Valued`" struct Valued end),
        constant = (@doc "constant `VALUED`" const VALUED = 1),
    )
    const VALUED_A = 1
    const VALUED_B = 2
end

module InnerModule

    import ..TemplateTests

    using DocStringExtensions

    @template DEFAULT = TemplateTests

    @template METHODS = TemplateTests

    @template MACROS =
        """
        (MACROS)

        $(DOCSTRING)

        $(SIGNATURES)
        """

    "constant `K`"
    const K = 1

    """
    mutable struct `T`

    $(FIELDS)
    """
    mutable struct T
        "field docs for x"
        x
    end

    "method `f`"
    f(x) = x

    "macro `@m`"
    macro m(x) end
end

module OtherModule

    import ..TemplateTests

    using DocStringExtensions

    @template TYPES = TemplateTests
    @template MACROS = TemplateTests.InnerModule

    "mutable struct `T`"
    mutable struct T end

    "mutable struct `ISSUE_115{S}`"
    mutable struct ISSUE_115{S} end

    "macro `@m`"
    macro m(x) end

    "method `f`"
    f(x) = x
end

# A template applies to the docstrings that follow it, not to earlier ones.
module LateTemplate

    using DocStringExtensions

    @template DEFAULT =
        """
        (DEFAULT)

        $(DOCSTRING)
        """

    "method `early`"
    early(x) = x

    @template METHODS =
        """
        (METHODS)

        $(DOCSTRING)
        """

    "method `late`"
    late(x) = x
end

end
