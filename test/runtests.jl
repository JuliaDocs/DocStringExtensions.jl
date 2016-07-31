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

immutable K
    K(; a = 1) = new()
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

        # Method signatures.
        doc.data = Dict(
            :binding => Docs.Binding(M, :f),
            :typesig => Tuple{Any},
            :module => M,
        )
        DSE.format(signatures, buf, doc)
        str = takebuf_string(buf)
        @test startswith(str, "# Signatures\n")
        @test contains(str, "\n```julia\n")
        @test contains(str, "\nf(x)\n")
        @test contains(str, "\n```\n")
    end
    @testset "utilities" begin
        @testset "filtermethods" begin
            let list = DSE.filtermethods(DSE.filtermethods, Tuple{Any, Any, Any}, DSE)
                @test length(list) == 1
            end
            let list = DSE.filtermethods(DSE.filtermethods, Tuple{Any, Any, Any}, Base)
                @test length(list) == 0
            end
            let list = DSE.filtermethods(DSE.filtermethods, Tuple{Any, Any}, DSE)
                @test length(list) == 0
            end
            let list = DSE.filtermethods(DSE.filtermethods, Union{}, DSE)
                @test length(list) == 1
            end
        end
        @testset "keywords" begin
            @test DSE.keywords(M.T, first(methods(M.T))) == Symbol[]
            @test DSE.keywords(M.K, first(methods(M.K))) == [:a]
            @test DSE.keywords(M.f, first(methods(M.f))) == Symbol[]
            let f = (() -> ()),
                m = first(methods(f))
                @test DSE.keywords(f, m) == Symbol[]
            end
            let f = ((a) -> ()),
                m = first(methods(f))
                @test DSE.keywords(f, m) == Symbol[]
            end
            let f = ((; a = 1) -> ()),
                m = first(methods(f))
                @test DSE.keywords(f, m) == [:a]
            end
            let f = ((; a = 1, b = 2) -> ()),
                m = first(methods(f))
                @test DSE.keywords(f, m) == [:a, :b]
            end
            let f = ((; a...) -> ()),
                m = first(methods(f))
                @test DSE.keywords(f, m) == [Symbol("a...")]
            end
        end
        @testset "arguments" begin
            @test DSE.arguments(first(methods(M.T))) == [:a, :b, :c]
            @test DSE.arguments(first(methods(M.K))) == Symbol[]
            @test DSE.arguments(first(methods(M.f))) == [:x]
            let m = first(methods(() -> ()))
                @test DSE.arguments(m) == Symbol[]
            end
            let m = first(methods((a) -> ()))
                @test DSE.arguments(m) == [:a]
            end
            let m = first(methods((; a = 1) -> ()))
                @test DSE.arguments(m) == Symbol[]
            end
            let m = first(methods((x; a = 1, b = 2) -> ()))
                @test DSE.arguments(m) == Symbol[:x]
            end
            let m = first(methods((; a...) -> ()))
                @test DSE.arguments(m) == Symbol[]
            end
        end
        @testset "printmethod" begin
            let b = Docs.Binding(M, :T),
                f = M.T,
                m = first(methods(f))
                @test DSE.printmethod(b, f, m) == "T(a, b, c)"
            end
            let b = Docs.Binding(M, :K),
                f = M.K,
                m = first(methods(f))
                @test DSE.printmethod(b, f, m) == "K(; a)"
            end
            let b = Docs.Binding(M, :f),
                f = M.f,
                m = first(methods(f))
                @test DSE.printmethod(b, f, m) == "f(x)"
            end
            let b = Docs.Binding(Main, :f),
                f = () -> (),
                m = first(methods(f))
                @test DSE.printmethod(b, f, m) == "f()"
            end
            let b = Docs.Binding(Main, :f),
                f = (a) -> (),
                m = first(methods(f))
                @test DSE.printmethod(b, f, m) == "f(a)"
            end
            let b = Docs.Binding(Main, :f),
                f = (; a = 1) -> (),
                m = first(methods(f))
                @test DSE.printmethod(b, f, m) == "f(; a)"
            end
            let b = Docs.Binding(Main, :f),
                f = (; a = 1, b = 2) -> (),
                m = first(methods(f))
                # Keywords are not ordered, so check for both combinations.
                @test DSE.printmethod(b, f, m) in ("f(; a, b)", "f(; b, a)")
            end
            let b = Docs.Binding(Main, :f),
                f = (; a...) -> (),
                m = first(methods(f))
                @test DSE.printmethod(b, f, m) == "f(; a...)"
            end
            let b = Docs.Binding(Main, :f),
                f = (; a = 1, b = 2, c...) -> (),
                m = first(methods(f))
                # Keywords are not ordered, so check for both combinations.
                @test DSE.printmethod(b, f, m) in ("f(; a, b, c...)", "f(; b, a, c...)")
            end
        end
    end
end

DSE.parsedocs(DSE)

