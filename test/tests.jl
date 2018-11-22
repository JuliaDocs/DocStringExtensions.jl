const DSE = DocStringExtensions

include("templates.jl")
include("TestModule/M.jl")

# initialize a test repo in test/TestModule which is needed for some tests
function with_test_repo(f)
    repo = LibGit2.init(joinpath(@__DIR__, "TestModule"))
    LibGit2.add!(repo, "M.jl")
    sig = LibGit2.Signature("zeptodoctor", "zeptodoctor@zeptodoctor.com", round(time()), 0)
    LibGit2.commit(repo, "M.jl", committer = sig, author = sig)
    LibGit2.GitRemote(repo, "origin", "https://github.com/JuliaDocs/NonExistent.jl.git")
    try
        f()
    finally
        rm(joinpath(@__DIR__, "TestModule", ".git"); force = true, recursive = true)
    end
end

@testset "DocStringExtensions" begin
    @testset "Base assumptions" begin
        # The package heavily relies on type and docsystem-related methods and types from
        # Base, which are generally undocumented and their behaviour might change at any
        # time. This set of tests is tests and documents the assumptions the package makes
        # about them.
        #
        # The testset is not comprehensive -- i.e. DocStringExtensions makes use of
        # undocumented features that are not tested here. Should you come across anything
        # like that, please add a test here.
        #

        # Getting keyword arguments of a method.
        #
        # Used in src/utilities.jl for the keywords() function.
        #
        # The methodology is based on a snippet in Base at base/replutil.jl:572-576
        # (commit 3b45cdc9aab0). It uses the undocumented Base.kwarg_decl() function.
        @test isdefined(Base, :kwarg_decl)
        # Its signature is kwarg_decl(m::Method, kwtype::DataType). The second argument
        # should be the type of the kwsorter from the corresponding MethodTable.
        @test isa(methods(M.j_1), Base.MethodList)
        @test isdefined(methods(M.j_1), :mt)
        local mt = methods(M.j_1).mt
        @test isa(mt, Core.MethodTable)
        @test isdefined(mt, :kwsorter)
        # .kwsorter is not always defined -- namely, it seems when none of the methods
        # have keyword arguments:
        @test isdefined(methods(M.f).mt, :kwsorter) === false
        # M.j_1 has two methods. Fetch the single argument one..
        local m = which(M.j_1, (Any,))
        @test isa(m, Method)
        # .. which should have a single keyword argument, :y
        # Base.kwarg_decl returns a Vector{Any} of the keyword arguments.
        local kwargs = Base.kwarg_decl(m, typeof(mt.kwsorter))
        @test isa(kwargs, Vector{Any})
        @test kwargs == [:y]
        # Base.kwarg_decl will return a Tuple{} for some reason when called on a method
        # that does not have any arguments
        m = which(M.j_1, (Any,Any)) # fetch the no-keyword method
        @test Base.kwarg_decl(m, typeof(methods(M.j_1).mt.kwsorter)) == Tuple{}()
    end
    @testset "format" begin
        # Setup.
        doc = Docs.DocStr(Core.svec(), nothing, Dict())
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
            str = String(take!(buf))
            @test occursin("\n  - `Base`\n", str)
            @test occursin("\n  - `Core`\n", str)

            # Module exports.
            DSE.format(EXPORTS, buf, doc)
            str = String(take!(buf))
            @test occursin("\n  - [`f`](@ref)\n", str)
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
            str = String(take!(buf))
            @test occursin("  - `a`", str)
            @test occursin("  - `b`", str)
            @test occursin("  - `c`", str)
            @test occursin("one", str)
            @test occursin("two", str)
        end

        @testset "method lists" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :f),
                :typesig => Tuple{Any},
                :module => M,
            )
            with_test_repo() do
                DSE.format(METHODLIST, buf, doc)
            end
            str = String(take!(buf))
            @test occursin("```julia", str)
            @test occursin("f(x)", str)
            @test occursin(joinpath("test", "TestModule", "M.jl"), str)
        end

        @testset "method signatures" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :f),
                :typesig => Tuple{Any},
                :module => M,
            )
            DSE.format(SIGNATURES, buf, doc)
            str = String(take!(buf))
            @test occursin("\n```julia\n", str)
            @test occursin("\nf(x)\n", str)
            @test occursin("\n```\n", str)

            doc.data = Dict(
                :binding => Docs.Binding(M, :g),
                :typesig => Union{Tuple{}, Tuple{Any}},
                :module => M,
            )
            DSE.format(SIGNATURES, buf, doc)
            str = String(take!(buf))
            @test occursin("\n```julia\n", str)
            @test occursin("\ng()\n", str)
            @test occursin("\ng(x)\n", str)
            @test occursin("\n```\n", str)

            doc.data = Dict(
                :binding => Docs.Binding(M, :g),
                :typesig => Union{Tuple{}, Tuple{Any}, Tuple{Any, Any}, Tuple{Any, Any, Any}},
                :module => M,
            )
            DSE.format(SIGNATURES, buf, doc)
            str = String(take!(buf))
            @test occursin("\n```julia\n", str)
            @test occursin("\ng()\n", str)
            @test occursin("\ng(x)\n", str)
            @test occursin("\ng(x, y)\n", str)
            @test occursin("\ng(x, y, z; kwargs...)\n", str)
            @test occursin("\n```\n", str)
        end

        @testset "function names" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :f),
                :typesig => Tuple{Any},
                :module => M,
            )
            DSE.format(FUNCTIONNAME, buf, doc)
            str = String(take!(buf))
            @test str == "f"
        end

        @testset "type definitions" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :AbstractType),
                :typesig => Union{},
                :module => M,
            )
            DSE.format(TYPEDEF, buf, doc)
            str = String(take!(buf))
            @test str == "\n```julia\nabstract type AbstractType <: Integer\n```\n\n"

            doc.data = Dict(
                :binding => Docs.Binding(M, :CustomType),
                :typesig => Union{},
                :module => M,
            )
            DSE.format(TYPEDEF, buf, doc)
            str = String(take!(buf))
            @test str == "\n```julia\nstruct CustomType{S, T<:Integer} <: Integer\n```\n\n"

            doc.data = Dict(
                :binding => Docs.Binding(M, :BitType8),
                :typesig => Union{},
                :module => M,
            )
            DSE.format(TYPEDEF, buf, doc)
            str = String(take!(buf))
            @test str == "\n```julia\nprimitive type BitType8 8\n```\n\n"

            doc.data = Dict(
                :binding => Docs.Binding(M, :BitType32),
                :typesig => Union{},
                :module => M,
            )
            DSE.format(TYPEDEF, buf, doc)
            str = String(take!(buf))
            @test str == "\n```julia\nprimitive type BitType32 <: Real 32\n```\n\n"
        end

        @testset "README/LICENSE" begin
            doc.data = Dict(:module => DocStringExtensions)
            DSE.format(README, buf, doc)
            str = String(take!(buf))
            @test occursin("*Extensions for Julia's docsystem.*", str)
            DSE.format(LICENSE, buf, doc)
            str = String(take!(buf))
            @test occursin("MIT \"Expat\" License", str)
        end
    end
    @testset "templates" begin
        let fmt = expr -> Markdown.plain(eval(:(@doc $expr)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.K)))
            @test occursin("(TYPES)", fmt(:(TemplateTests.T)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.f)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.g)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.@m)))

            @test occursin("(DEFAULT)", fmt(:(TemplateTests.InnerModule.K)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.InnerModule.T)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.InnerModule.f)))
            @test occursin("(MACROS)", fmt(:(TemplateTests.InnerModule.@m)))

            @test occursin("(TYPES)", fmt(:(TemplateTests.OtherModule.T)))
            @test occursin("(MACROS)", fmt(:(TemplateTests.OtherModule.@m)))
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
            # Tests for #42
            let f = M.i_1, m = first(methods(f))
                @test DSE.keywords(f, m) == [:y]
            end
            let f = M.i_2, m = first(methods(f))
                @test DSE.keywords(f, m) == [:y]
            end
            let f = M.i_3, m = first(methods(f))
                @test DSE.keywords(f, m) == [:y]
            end
            let f = M.i_4, m = first(methods(f))
                @test DSE.keywords(f, m) == [:y, :z]
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
            @test length(DSE.getmethods(M.h_3, Tuple{M.A{Int}})) == 1
            @test length(DSE.getmethods(M.h_3, Tuple{Vector{Int}})) == 1
            @test length(DSE.getmethods(M.h_3, Tuple{Array{Int, 3}})) == 0
        end
        @testset "methodgroups" begin
            @test length(DSE.methodgroups(M.f, Tuple{Any}, M)) == 1
            @test length(DSE.methodgroups(M.f, Tuple{Any}, M)[1]) == 1
            @test length(DSE.methodgroups(M.h_1, Tuple{M.A}, M)) == 1
            @test length(DSE.methodgroups(M.h_1, Tuple{M.A}, M)[1]) == 1
            @test length(DSE.methodgroups(M.h_2, Tuple{M.A{Int}}, M)) == 1
            @test length(DSE.methodgroups(M.h_2, Tuple{M.A{Int}}, M)[1]) == 1
            @test length(DSE.methodgroups(M.h_3, Tuple{M.A}, M)[1]) == 1
        end
        @testset "alltypesigs" begin
            @test DSE.alltypesigs(Union{}) == Any[]
            @test DSE.alltypesigs(Union{Tuple{}}) == Any[Tuple{}]
            @test DSE.alltypesigs(Tuple{}) == Any[Tuple{}]

            # TODO: Clean me up
            T = Type{T} where {T}
            @test DSE.alltypesigs(T) ==
                Base.rewrap_unionall.(DSE.uniontypes(Base.unwrap_unionall(T)), T)
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
            with_test_repo() do
                @test occursin("github.com/JuliaDocs/NonExistent", DSE.url(first(methods(M.f))))
                @test occursin("github.com/JuliaDocs/NonExistent", DSE.url(first(methods(M.K))))
            end
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
