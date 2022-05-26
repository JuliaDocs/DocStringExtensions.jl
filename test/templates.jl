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

end
