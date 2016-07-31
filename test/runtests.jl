using DocStringExtensions
using Base.Test

const DSE = DocStringExtensions

module M

export f

f(x) = x

type T
    a
    b
    c
end

end

@testset "" begin
    @testset "format" begin
        # Setup.
        doc = Docs.DocStr(Core.svec(), Nullable(), Dict())
        buf = IOBuffer()

        # Errors.
        @test_throws ErrorException DSE.format(nothing, buf, doc)

        # Module imports.
        doc.data = Dict(
            :binding => Docs.Binding(Main, :M),
            :typesig => Union{},
        )
        DSE.format(imports, buf, doc)
        @test takebuf_string(buf) ==
        """
        # Imports

          - `Base`
          - `Core`

        """

        # Module exports.
        DSE.format(exports, buf, doc)
        @test takebuf_string(buf) ==
        """
        # Exports

          - [`f`](@ref)

        """

        # Type fields.
        doc.data = Dict(
            :binding => Docs.Binding(M, :T),
            :fields => Dict(
                :a => "one",
                :b => "two",
            ),
        )
        DSE.format(fields, buf, doc)
        str = takebuf_string(buf)
        @test startswith(str, "# Fields\n")
        @test contains(str, "  - `a`")
        @test contains(str, "  - `b`")
        @test contains(str, "  - `c`")
        @test contains(str, "one")
        @test contains(str, "two")

        # Method lists.
        doc.data = Dict(
            :binding => Docs.Binding(M, :f),
            :typesig => Tuple{Any},
            :module => M,
        )
        DSE.format(methodlist, buf, doc)
        str = takebuf_string(buf)
        @test startswith(str, "# Methods\n")
        @test contains(str, " - ```")
        @test contains(str, "f(x) at ")
        @test contains(str, @__FILE__)
    end
    @testset "utilities" begin
        list = DSE.filtermethods(DSE.filtermethods, Tuple{Any, Any, Any}, DSE)
        @test length(list) == 1
        list = DSE.filtermethods(DSE.filtermethods, Tuple{Any, Any, Any}, Base)
        @test length(list) == 0
        list = DSE.filtermethods(DSE.filtermethods, Tuple{Any, Any}, DSE)
        @test length(list) == 0
        list = DSE.filtermethods(DSE.filtermethods, Union{}, DSE)
        @test length(list) == 1
    end
end

DSE.parsedocs(DSE)

