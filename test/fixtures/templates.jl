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

    @template ABSTRACTTYPES =
    """
    (ABSTRACTTYPES)

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

    "constant `U{S}`"
    const U{S} = Union{S, Nothing}

    "mutable struct `T`"
    mutable struct T end

    "abstract type `A`"
    abstract type A end

    "abstract type `AP{S}`"
    abstract type AP{S} end

    "primitive type `P`"
    primitive type P 8 end

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

    r(x) = x
    Core.@doc "method `r` documented with `define = false`, as Revise does" r(x) = x false

    "method `early` documented before it is defined"
    early(x)
    early(x) = x

    function bare end
    "function `bare` documented by its bare name"
    bare

    "name `never_defined` documented but never defined"
    TemplateTests.never_defined

    const aliased = f
    "method `f` defined through the alias `aliased`"
    aliased(x::Int) = x

    struct Point{N} end
    const Point2 = Point{2}
    "constructor `Point{2}` defined through the alias `Point2`"
    Point2(x::Int) = Point{2}()

    struct Inner
        x
        @doc "inner constructor `Inner`" Inner(x::Int) = new(x)
    end

    struct InnerParametric{T}
        x::T
        @doc "inner constructor `InnerParametric`" InnerParametric(x::T) where {T} = new{T}(x)
    end

    const DOC_VALUE = @doc "method `valued`" valued(x) = x

    paired(x) = x
    struct Paired end
    @doc "function `paired` and type `Paired`" (paired, Paired)

    "module `Documented`"
    module Documented end

    module Redocumented end
    Core.@doc "module `Redocumented` documented with `define = false`" module Redocumented end false

    """
    method `opted_out`

    $(NOTEMPLATE)
    """
    opted_out(x) = x

    """
    method `early_opted_out` documented before it is defined

    $(NOTEMPLATE)
    """
    early_opted_out(x)
    early_opted_out(x) = x

    """
    `@kwdef` struct `OptedOut`

    $(NOTEMPLATE)
    """
    Base.@kwdef struct OptedOut end

    """
    method `redirected`

    $(DocStringExtensions.TemplateOverride(:DEFAULT))
    """
    redirected(x) = x

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

        # A function named like a macro is not one. `var"@f"` does not parse on Julia 1.0.
        @eval @doc "function `@notmacro`" $(Symbol("@notmacro"))(a) = a

        """
        mutable struct `T`

        $(FIELDS)
        """
        mutable struct T
            "field docs for x"
            x
        end

        "abstract type `A`"
        abstract type A end

        "method `f`"
        f(x) = x

        "macro `@m`"
        macro m(x) end
    end

    module LateTemplate

        using DocStringExtensions

        "method `before`"
        before(x) = x

        @template DEFAULT =
        """
        (LATE)

        $(DOCSTRING)
        """

        "method `after`"
        after(x) = x
    end

    module BlockTemplate

        using DocStringExtensions

        begin
            @template DEFAULT =
            """
            (BLOCK)

            $(DOCSTRING)
            """

            "method `inside`"
            inside(x) = x
        end
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

        "abstract type `A`"
        abstract type A end

        "macro `@m`"
        macro m(x) end

        "method `f`"
        f(x) = x
    end

end

module Untemplated

    const DOC_VALUE = @doc "method `valued`" valued(x) = x

end
