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

"type `T`"
type T end

"method `f`"
f(x) = x

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

    "type `T`"
    type T end

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

    "type `T`"
    type T end

    "macro `@m`"
    macro m(x) end

    "method `f`"
    f(x) = x
end

end
