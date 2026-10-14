@testset "METHODLIST" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
    @testset "method lists" begin
        doc.data = Dict(
            :binding => Docs.Binding(M, :f),
            :typesig => Tuple{Any},
            :module => M,
        )
        str = with_test_repo(() -> formatted(METHODLIST, doc))
        @test_reference method_lists_reference() redact_local_info(str)

        # The redaction must not depend on the name of the checkout directory.
        url = "](https://github.com/JuliaDocs/NonExistent.jl/tree/0123abc/M.jl#L5)."
        installed = "defined at [`packages/DocStringExtensions/Ab1Cd/test/fixtures/TestModule/M.jl:5`" * url
        @test redact_local_info(installed) ==
            "defined at [`[...]test/fixtures/TestModule/M.jl:5`](https://github.com/JuliaDocs/NonExistent.jl/tree/[...]/M.jl#L5)."
        windows = "defined at [`C:\\Users\\u\\.julia\\dev\\DocStringExtensions\\test\\fixtures\\TestModule\\M.jl:5`" * url
        @test redact_local_info(windows) ==
            "defined at [`[...]test\\fixtures\\TestModule\\M.jl:5`](https://github.com/JuliaDocs/NonExistent.jl/tree/[...]/M.jl#L5)."

        doc.data = Dict(
            :binding => Docs.Binding(M, :l_1),
            :typesig => Union{},
            :module => M,
        )
        str = with_test_repo(() -> formatted(DSE.MethodList(returns = true), doc))
        @test_reference typed_method_lists_reference("method_lists_returns") redact_local_info(str)

        # Each listed method has its own return type, so a list takes no fixed text.
        @test_throws TypeError DSE.MethodList(returns = "success::Bool")
        @test_throws TypeError DSE.TypedMethodList(returns = "success::Bool")
    end

    @testset "method lists with types" begin
        doc.data = Dict(
            :binding => Docs.Binding(M, :l_1),
            :typesig => Union{},
            :module => M,
        )
        str = with_test_repo(() -> formatted(TYPEDMETHODLIST, doc))
        @test_reference typed_method_lists_reference("typed_method_lists") redact_local_info(str)

        str = with_test_repo(() -> formatted(DSE.TypedMethodList(returns = false), doc))
        @test_reference typed_method_lists_reference("typed_method_lists_no_return") redact_local_info(str)

        # Each method shows its own return type when the signatures overlap.
        doc.data = Dict(
            :binding => Docs.Binding(M, :overlapping),
            :typesig => Union{},
            :module => M,
        )
        str = with_test_repo(() -> formatted(TYPEDMETHODLIST, doc))
        @test_reference method_lists_reference("typed_method_lists_overlapping") redact_local_info(str)
    end

    # A type's list holds the methods of its constructors, and not the callables of its
    # instances. The link names this checkout's commit, so it is dropped.
    @testset "callable lists" begin
        str = rendered(:(CallablesTestModule.Listed))
        @test_reference ro_path("method_lists_callables.txt") replace(str, r"defined at .*\n\n" => "")
    end

    # A parametric type's list holds its constructors written `T{P}(...)`.
    @testset "parametric constructor lists" begin
        str = rendered(:(ConstructorsTestModule.Scaled))
        @test_reference ro_path("method_lists_parametric_constructors.txt") replace(str, r"defined at .*\n\n" => "")
    end

    # A macro lists without `__source__` and `__module__`. The link names this checkout's
    # commit, so it is dropped.
    @testset "macro lists" begin
        str = rendered(:(MacrosTestModule.$(Symbol("@listed"))))
        @test_reference ro_path("method_lists_macros.txt") replace(str, r"defined at .*\n\n" => "")
    end

    @testset "url" begin
        @test !isempty(DSE.url(first(methods(sin))))
        with_test_repo() do
            @test occursin("github.com/JuliaDocs/NonExistent", DSE.url(first(methods(M.f))))
            @test occursin("github.com/JuliaDocs/NonExistent", DSE.url(first(methods(M.K))))
        end
        withenv(
            "TRAVIS_REPO_SLUG" => "JuliaDocs/NonExistent",
            "TRAVIS_COMMIT" => "<commit>",
            "TRAVIS_BUILD_DIR" => dirname(dirname(@__DIR__))
        ) do
            @test occursin("github.com/JuliaDocs/NonExistent/tree/<commit>/test/fixtures/TestModule/M.jl", DSE.url(first(methods(M.f))))
        end
    end

    @testset "sourcepath" begin
        # A package module's files are shown relative to the package root, wherever it lives.
        file = string(first(methods(DSE.cleanpath)).file)
        @test DSE.sourcepath(file, DSE) == "src/abbreviations/methodlist.jl"
        file = string(first(methods(Nested.Inner.f)).file)
        @test DSE.sourcepath(file, Nested.Inner) == "src/inner/Inner.jl"
        # `M` is not part of a package.
        file = string(first(methods(M.f)).file)
        @test DSE.sourcepath(file, M) == DSE.cleanpath(file)
    end
end
