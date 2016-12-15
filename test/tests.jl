
const DSE = DocStringExtensions

include("templates.jl")

module M

export f

f(x) = x

g(x = 1, y = 2, z = 3; kwargs...) = x

typealias A{T} Union{Vector{T}, Matrix{T}}

h_1(x::A) = x
h_2(x::A{Int}) = x

type T
    a
    b
    c
end

immutable K
    K(; a = 1) = new()
end


abstract AbstractType <: Integer

immutable CustomType{S, T <: Integer} <: Integer
end

bitstype 8 BitType8

bitstype 32 BitType32 <: Real

end

@testset "" begin
    @testset "format" begin
        # Setup.
        doc = Docs.DocStr(Core.svec(), Nullable(), Dict())
        buf = IOBuffer()

        # Errors.
        @test_throws ErrorException DSE.format(nothing, buf, doc)

        @testset "imports & exports" begin
            # Module imports.
            doc.data = Dict(
                :binding => Docs.Binding(Main, :M),
                :typesig => Union{},
            )
            DSE.format(IMPORTS, buf, doc)
            str = DSE.takebuf_str(buf)
            @test contains(str, "\n  - `Base`\n")
            @test contains(str, "\n  - `Core`\n")

            # Module exports.
            DSE.format(EXPORTS, buf, doc)
            str = DSE.takebuf_str(buf)
            @test contains(str, "\n  - [`f`](@ref)\n")
        end

        @testset "type fields" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :T),
                :fields => Dict(
                    :a => "one",
                    :b => "two",
                ),
            )
            DSE.format(FIELDS, buf, doc)
            str = DSE.takebuf_str(buf)
            @test contains(str, "  - `a`")
            @test contains(str, "  - `b`")
            @test contains(str, "  - `c`")
            @test contains(str, "one")
            @test contains(str, "two")
        end

        @testset "method lists" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :f),
                :typesig => Tuple{Any},
                :module => M,
            )
            DSE.format(METHODLIST, buf, doc)
            str = DSE.takebuf_str(buf)
            @test contains(str, "```julia")
            @test contains(str, "f(x)")
            @test contains(str, "[`$(joinpath("DocStringExtensions", "test", "tests.jl"))")
        end

        @testset "method signatures" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :f),
                :typesig => Tuple{Any},
                :module => M,
            )
            DSE.format(SIGNATURES, buf, doc)
            str = DSE.takebuf_str(buf)
            @test contains(str, "\n```julia\n")
            @test contains(str, "\nf(x)\n")
            @test contains(str, "\n```\n")

            doc.data = Dict(
                :binding => Docs.Binding(M, :g),
                :typesig => Union{Tuple{}, Tuple{Any}},
                :module => M,
            )
            DSE.format(SIGNATURES, buf, doc)
            str = DSE.takebuf_str(buf)
            @test contains(str, "\n```julia\n")
            @test contains(str, "\ng()\n")
            @test contains(str, "\ng(x)\n")
            @test contains(str, "\n```\n")

            doc.data = Dict(
                :binding => Docs.Binding(M, :g),
                :typesig => Union{Tuple{}, Tuple{Any}, Tuple{Any, Any}, Tuple{Any, Any, Any}},
                :module => M,
            )
            DSE.format(SIGNATURES, buf, doc)
            str = DSE.takebuf_str(buf)
            @test contains(str, "\n```julia\n")
            @test contains(str, "\ng()\n")
            @test contains(str, "\ng(x)\n")
            @test contains(str, "\ng(x, y)\n")
            @test contains(str, "\ng(x, y, z; kwargs...)\n")
            @test contains(str, "\n```\n")
        end

        @testset "type definitions" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :AbstractType),
                :typesig => Union{},
                :module => M,
            )
            DSE.format(TYPEDEF, buf, doc)
            str = DSE.takebuf_str(buf)
            @test contains(str, "\n```julia\n")
            @test contains(str, "\nabstract AbstractType <: Integer\n")
            @test contains(str, "\n```\n")

            doc.data = Dict(
                :binding => Docs.Binding(M, :CustomType),
                :typesig => Union{},
                :module => M,
            )
            DSE.format(TYPEDEF, buf, doc)
            str = DSE.takebuf_str(buf)
            @test contains(str, "\n```julia\n")
            @test contains(str, "\nimmutable CustomType{S, T<:Integer} <: Integer\n")
            @test contains(str, "\n```\n")

            doc.data = Dict(
                :binding => Docs.Binding(M, :BitType8),
                :typesig => Union{},
                :module => M,
            )
            DSE.format(TYPEDEF, buf, doc)
            str = DSE.takebuf_str(buf)
            @test contains(str, "\n```julia\n")
            @test contains(str, "\nbitstype 8 BitType8\n")
            @test contains(str, "\n```\n")

            doc.data = Dict(
                :binding => Docs.Binding(M, :BitType32),
                :typesig => Union{},
                :module => M,
            )
            DSE.format(TYPEDEF, buf, doc)
            str = DSE.takebuf_str(buf)
            @test contains(str, "\n```julia\n")
            @test contains(str, "\nbitstype 32 BitType32 <: Real")
            @test contains(str, "\n```\n")
        end
    end
    @testset "templates" begin
        let fmt = expr -> Markdown.plain(eval(:(@doc $expr)))
            @test contains(fmt(:(TemplateTests.K)), "(DEFAULT)")
            @test contains(fmt(:(TemplateTests.T)), "(TYPES)")
            @test contains(fmt(:(TemplateTests.f)), "(METHODS, MACROS)")
            @test contains(fmt(:(TemplateTests.@m)), "(METHODS, MACROS)")

            @test contains(fmt(:(TemplateTests.InnerModule.K)), "(DEFAULT)")
            @test contains(fmt(:(TemplateTests.InnerModule.T)), "(DEFAULT)")
            @test contains(fmt(:(TemplateTests.InnerModule.f)), "(METHODS, MACROS)")
            @test contains(fmt(:(TemplateTests.InnerModule.@m)), "(MACROS)")

            @test contains(fmt(:(TemplateTests.OtherModule.T)), "(TYPES)")
            @test contains(fmt(:(TemplateTests.OtherModule.@m)), "(MACROS)")
            @test fmt(:(TemplateTests.OtherModule.f)) == "method `f`\n"
        end
    end
    @testset "utilities" begin
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
        @testset "getmethods" begin
            @test length(DSE.getmethods(M.f, Union{})) == 1
            @test length(DSE.getmethods(M.f, Tuple{})) == 0
            @test length(DSE.getmethods(M.f, Union{Tuple{}, Tuple{Any}})) == 1
        end
        @testset "methodgroups" begin
            @test length(DSE.methodgroups(M.f, Tuple{Any}, M)) == 1
            @test length(DSE.methodgroups(M.f, Tuple{Any}, M)[1]) == 1
            @test length(DSE.methodgroups(M.h_1, Tuple{M.A}, M)) == 1
            @test length(DSE.methodgroups(M.h_1, Tuple{M.A}, M)[1]) == 1
            @test length(DSE.methodgroups(M.h_2, Tuple{M.A{Int}}, M)) == 1
            @test length(DSE.methodgroups(M.h_2, Tuple{M.A{Int}}, M)[1]) == 1
        end
        @testset "alltypesigs" begin
            @test DSE.alltypesigs(Union{}) == Any[]
            @test DSE.alltypesigs(Union{Tuple{}}) == Any[Tuple{}]
            @test DSE.alltypesigs(Tuple{}) == Any[Tuple{}]
        end
        @testset "groupby" begin
            let groups = DSE.groupby(Int, Vector{Int}, collect(1:10)) do each
                    mod(each, 3), each
                end
                @test groups == Pair{Int, Vector{Int}}[
                    0 => [3, 6, 9],
                    1 => [1, 4, 7, 10],
                    2 => [2, 5, 8],
                ]
            end
        end
        @testset "url" begin
            @test !isempty(DSE.url(first(methods(sin))))
            @test !isempty(DSE.url(first(methods(DSE.parsedocs))))
            @test !isempty(DSE.url(first(methods(M.f))))
            @test !isempty(DSE.url(first(methods(M.K))))
        end
        @testset "comparemethods" begin
            let f = first(methods(M.f)),
                g = first(methods(M.g))
                @test !DSE.comparemethods(f, f)
                @test DSE.comparemethods(f, g)
                @test !DSE.comparemethods(g, f)
            end
        end
    end
end

DSE.parsedocs(DSE)

