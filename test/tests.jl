const DSE = DocStringExtensions

include("templates.jl")
include("interpolation.jl")
include("TestModule/M.jl")

# initialize a test repo in test/TestModule which is needed for some tests
function with_test_repo(f)
    repo = LibGit2.init(joinpath(@__DIR__, "TestModule"))
    LibGit2.add!(repo, "M.jl")
    sig = LibGit2.Signature("zeptodoctor", "zeptodoctor@zeptodoctor.com", round(time()), 0)
    LibGit2.commit(repo, "M.jl", committer=sig, author=sig)
    LibGit2.GitRemote(repo, "origin", "https://github.com/JuliaDocs/NonExistent.jl.git")
    try
        f()
    finally
        rm(joinpath(@__DIR__, "TestModule", ".git"); force=true, recursive=true)
    end
end

ro_path(fn) = joinpath(@__DIR__, "reference_outputs", fn)

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
        get_mt(func) = VERSION ≥ v"1.12" ? Core.methodtable : methods(func).mt
        local mt = get_mt(M.j_1)
        @test isa(mt, Core.MethodTable)
        if Base.fieldindex(Core.MethodTable, :kwsorter, false) > 0
            @test isdefined(mt, :kwsorter)
        end
        # .kwsorter is not always defined -- namely, it seems when none of the methods
        # have keyword arguments:
        @test isdefined(get_mt(M.f), :kwsorter) === false
        # M.j_1 has two methods. Fetch the single argument one..
        local m = which(M.j_1, (Any,))
        @test isa(m, Method)
        # .. which should have a single keyword argument, :y
        # Base.kwarg_decl returns a Vector{Any} of the keyword arguments.
        local kwargs = VERSION < v"1.4.0-DEV.215" ? Base.kwarg_decl(m, typeof(mt.kwsorter)) : Base.kwarg_decl(m)
        @test isa(kwargs, Vector)
        @test kwargs == [:y]
        # Base.kwarg_decl will return a Tuple{} for some reason when called on a method
        # that does not have any arguments
        m = which(M.j_1, (Any, Any)) # fetch the no-keyword method
        if VERSION < v"1.4.0-DEV.215"
            @test Base.kwarg_decl(m, typeof(get_mt(M.j_1).kwsorter)) == Tuple{}()
        else
            @test Base.kwarg_decl(m) == []
        end
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
            str = @io2str DSE.format(IMPORTS, ::IO, doc)

            if VERSION < v"1.12"
                @test_reference ro_path("module_imports_pre_112.txt") str
            else
                @test_reference ro_path("module_imports_112_and_after.txt") str
            end

            # Module exports.
            str = @io2str DSE.format(EXPORTS, ::IO, doc)
            @test_reference ro_path("module_exports.txt") str
        end

        @testset "type fields" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :T),
                :fields => Dict(
                    :a => "one",
                    :b => "two",
                ),
            )
            str = @io2str DSE.format(FIELDS, ::IO, doc)
            @test_reference ro_path("fields.txt") str

            str = @io2str DSE.format(TYPEDFIELDS, ::IO, doc)
            @test_reference ro_path("typed_fields.txt") str
        end

        @testset "method lists" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :f),
                :typesig => Tuple{Any},
                :module => M,
            )
            str = @io2str with_test_repo() do
                DSE.format(METHODLIST, ::IO, doc)
            end
            # split into multiple replace() calls for older
            # versions of julia where the replace(s, r => s, r => s...)
            # method is missing
            remove_local_info = x -> begin
                x = replace(
                    x,
                    # remove the part of the path that precedes DocStringExtensions.jl/...
                    # because it will differ per machine
                    Regex("(defined at \\[`).+(DocStringExtensions.jl)") => s"\1[...]\2",
                )
                replace(
                    x,
                    # Remove the git hash because it will differ per
                    # test run
                    r"(tree/).+(/M)" => s"\1[...]\2"
                )
            end
            # the replacements are needed because the local
            # Git repo created by with_test_repo() will have
            # a different commit hash each time the test suite is run
            # and METHODLIST displays that. Reference tests will fail every
            # time if we don't remove the hash and the local part of the 
            # path
            if Sys.iswindows()
                @test_reference ro_path("method_lists_windows.txt") remove_local_info(str)
            else
                @test_reference ro_path("method_lists_nonwindows.txt") remove_local_info(str)
            end
        end

        @testset "method signatures" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :f),
                :typesig => Tuple{Any},
                :module => M,
            )
            str = @io2str DSE.format(SIGNATURES, ::IO, doc)
            @test_reference ro_path("method_signatures.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :g),
                :typesig => Union{Tuple{},Tuple{Any}},
                :module => M,
            )
            str = @io2str DSE.format(SIGNATURES, ::IO, doc)
            # On 1.10+, automatically generated methods have keywords in the metadata,
            # hence the display difference between Julia versions.
            if VERSION >= v"1.10"
                @test_reference ro_path("signatures_110_and_later.txt") str
            else
                @test_reference ro_path("signatures_pre_110.txt") str
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :g),
                :typesig => Union{Tuple{},Tuple{Any},Tuple{Any,Any},Tuple{Any,Any,Any}},
                :module => M,
            )
            str = @io2str DSE.format(SIGNATURES, ::IO, doc)
            # On 1.10+, automatically generated methods have keywords in the metadata,
            # hence the display difference between Julia versions.
            if VERSION >= v"1.10"
                @test_reference ro_path("signatures_many_tuples_110_and_later.txt") str
            else
                @test_reference ro_path("signatures_many_tuples_pre_110.txt") str
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :g_1),
                :typesig => Tuple{Any},
                :module => M,
            )
            str = @io2str DSE.format(SIGNATURES, ::IO, doc)
            @test_reference ro_path("signatures_tuple_any.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :h_4),
                :typesig => Union{Tuple{Any,Int,Any}},
                :module => M,
            )
            str = @io2str DSE.format(SIGNATURES, ::IO, doc)
            @test_reference ro_path("signatures_union_tuple_int_any.txt") str
        end

        @testset "method signatures with types" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :h_1),
                :typesig => Tuple{M.A},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            str = replace(str, " " => "")
            if Sys.iswindows() && VERSION < v"1.8"
                @test_reference ro_path("typed_method_signatures_windows_pre_18.txt") str
            else
                @test_reference ro_path("typed_method_signatures_not_windows_or_not_pre_18.txt") str
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :g_2),
                :typesig => Tuple{String},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            @test_reference ro_path("typed_method_signatures_tuple_string.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :h),
                :typesig => Tuple{Int,Int,Int},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            if typeof(1) === Int64
                @test_reference ro_path("typed_method_signatures_64bit.txt") str
            else
                @test_reference ro_path("typed_method_signatures_32bit.txt") str
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :h),
                :typesig => Tuple{Int},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            if typeof(1) === Int64
                # On 1.10+, automatically generated methods have keywords in the metadata,
                # hence the display difference between Julia versions.
                if VERSION >= v"1.10"
                    @test_reference ro_path("typed_method_signatures_64bit_110_and_later.txt") str
                else
                    @test_reference ro_path("typed_method_signatures_64bit_pre_110.txt") str
                end
            else
                # On 1.10+, automatically generated methods have keywords in the metadata,
                # hence the display difference between Julia versions.
                if VERSION >= v"1.10"
                    @test_reference ro_path("typed_method_signatures_32bit_110_and_later.txt") str
                else
                    @test_reference ro_path("typed_method_signatures_32bit_pre_110.txt") str
                end
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_0),
                :typesig => Tuple{T} where T,
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            @test_reference ro_path("typed_method_signatures_k0.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_1),
                :typesig => Union{Tuple{String},Tuple{String,T},Tuple{String,T,T},Tuple{T}} where T<:Number,
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            @test_reference ro_path("typed_method_signatures_k1.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_2),
                :typesig => (Union{Tuple{String,U,T},Tuple{T},Tuple{U}} where T<:Number) where U<:Complex,
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            @test_reference ro_path("typed_method_signatures_k2.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_3),
                :typesig => (Union{Tuple{Any,T,U},Tuple{U},Tuple{T}} where U<:Any) where T<:Any,
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            @test_reference ro_path("typed_method_signatures_k3.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_4),
                :typesig => Union{Tuple{String},Tuple{String,Int}},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            if VERSION > v"1.3.0"
                if typeof(1) === Int64
                    @test_reference ro_path("typed_method_signatures_k4_post_13_64bit.txt") str
                else
                    @test_reference ro_path("typed_method_signatures_k4_post_13_32bit.txt") str
                end
            else
                # TODO: remove this test when julia 1.0.0 support is dropped.
                # older versions of julia seem to return this
                # str = "\n```julia\nk_4(#temp#::String)\nk_4(#temp#::String, #temp#::Int64)\n\n```\n\n"
                @test_reference ro_path("typed_method_signatures_k4_up_to_13.txt") str
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_5),
                :typesig => Union{Tuple{Type{T},String},Tuple{Type{T},String,Union{Nothing,Function}},Tuple{T}} where T<:Number,
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            if VERSION > v"1.3.0"
                @test_reference ro_path("typed_method_signatures_k5_post_13.txt") str
            else
                # TODO: remove this test when julia 1.0.0 support is dropped.
                # older versions of julia seem to return this
                # str = "\n```julia\nk_5(#temp#::Type{T<:Number}, x::String) -> String\nk_5(#temp#::Type{T<:Number}, x::String, func::Union{Nothing, Function}) -> String\n\n```\n\n"
                @test_reference ro_path("typed_method_signatures_k5_up_to_13.txt") str
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_6),
                :typesig => Union{Tuple{Vector{T}},Tuple{T}} where T<:Number,
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            if VERSION >= v"1.6.0"
                @test_reference ro_path("typed_method_signatures_k6_16_and_later.txt") str
            else
                # TODO: remove this test when julia 1.0.0 support is dropped.
                @test_reference ro_path("typed_method_signatures_k6_pre_16.txt") str
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_7),
                :typesig => Union{Tuple{Union{Nothing,T}},Tuple{T},Tuple{Union{Nothing,T},T}} where T<:Integer,
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            if VERSION >= v"1.6" && VERSION < v"1.7"
                @test_reference ro_path("typed_method_signatures_k7_all_16_versions.txt") str
            else
                @test_reference ro_path("typed_method_signatures_k7_not_16.txt") str
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_8),
                :typesig => Union{Tuple{Any}},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            @test_reference ro_path("typed_method_signatures_k8.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_9),
                :typesig => Union{Tuple{T where T}},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
            @test_reference ro_path("typed_method_signatures_k9.txt") str

            @static if VERSION > v"1.5-" # see JuliaLang/#40405

                doc.data = Dict(
                    :binding => Docs.Binding(M, :k_11),
                    :typesig => Union{Tuple{Int,Vararg{Any}}},
                    :module => M,
                )
                str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
                @test_reference ro_path("typed_method_signatures_k11.txt") str

                doc.data = Dict(
                    :binding => Docs.Binding(M, :k_12),
                    :typesig => Union{Tuple{Int,Vararg{Real}}},
                    :module => M,
                )
                str = @io2str DSE.format(DSE.TYPEDSIGNATURES, ::IO, doc)
                @test_reference ro_path("typed_method_signatures_k12.txt") str
            end


        end

        @testset "method signatures with types (no return type)" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :h_1),
                :typesig => Tuple{M.A},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TypedMethodSignatures(false), ::IO, doc)
            str = replace(str, " " => "")
            if Sys.iswindows() && VERSION < v"1.8"
                @test_reference ro_path("typed_method_signatures_no_return_h1_windows_pre_18.txt") str
            else
                @test_reference ro_path("typed_method_signatures_no_return_h1_not_windows_or_18_and_later.txt") str
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :g_2),
                :typesig => Tuple{String},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TypedMethodSignatures(false), ::IO, doc)
            @test_reference ro_path("typed_method_signatures_no_return_g2.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :h),
                :typesig => Tuple{Int,Int,Int},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TypedMethodSignatures(false), ::IO, doc)
            if typeof(1) === Int64
                @test_reference ro_path("typed_method_signatures_no_return_h_64bit.txt") str
            else
                @test_reference ro_path("typed_method_signatures_no_return_h_not64bit.txt") str
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :h),
                :typesig => Tuple{Int},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TypedMethodSignatures(false), ::IO, doc)
            if typeof(1) === Int64
                # On 1.10+, automatically generated methods have keywords in the metadata,
                # hence the display difference between Julia versions.
                if VERSION >= v"1.10"
                    @test_reference ro_path("typed_method_signatures_no_return_h_64bit_110_and_later.txt") str
                else
                    @test_reference ro_path("typed_method_signatures_no_return_h_64bit_pre_110.txt") str
                end
            else
                # On 1.10+, automatically generated methods have keywords in the metadata,
                # hence the display difference between Julia versions.
                if VERSION >= v"1.10"
                    @test_reference ro_path("typed_method_signatures_no_return_h_not_64bit_110_and_later.txt") str
                else
                    @test_reference ro_path("typed_method_signatures_no_return_h_not_64bit_pre_110.txt") str
                end
            end

        end

        @testset "function names" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :f),
                :typesig => Tuple{Any},
                :module => M,
            )
            str = @io2str DSE.format(DSE.FUNCTIONNAME, ::IO, doc)
            @test_reference ro_path("function_names.txt") str
        end

        @testset "type definitions" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :AbstractType1),
                :typesig => Union{},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDEF, ::IO, doc)
            @test_reference ro_path("typedef1.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :AbstractType2),
                :typesig => Union{},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDEF, ::IO, doc)
            @test_reference ro_path("typedef2.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :CustomType),
                :typesig => Union{},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDEF, ::IO, doc)
            @test_reference ro_path("typedef_custom.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :BitType8),
                :typesig => Union{},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDEF, ::IO, doc)
            @test_reference ro_path("typedef_bittype8.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :BitType32),
                :typesig => Union{},
                :module => M,
            )
            str = @io2str DSE.format(DSE.TYPEDEF, ::IO, doc)
            @test_reference ro_path("typedef_bittype32.txt") str
        end

        @testset "README/LICENSE" begin
            doc.data = Dict(:module => DocStringExtensions)
            str = @io2str DSE.format(DSE.README, ::IO, doc)
            @test_reference ro_path("readme.txt") str
            str = @io2str DSE.format(DSE.LICENSE, ::IO, doc)
            @test_reference ro_path("license.txt") str
        end
    end
    @testset "templates" begin
        let fmt = expr -> Markdown.plain(eval(:(@doc $expr)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.K)))
            @test occursin("(TYPES)", fmt(:(TemplateTests.T)))
            @test occursin("(TYPES)", fmt(:(TemplateTests.S)))
            @test occursin("(TYPES)", fmt(:(TemplateTests.ISSUE_115)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.f)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.g)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.h)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.@m)))

            @test occursin("(DEFAULT)", fmt(:(TemplateTests.InnerModule.K)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.InnerModule.T)))
            @test occursin("field docs for x", fmt(:(TemplateTests.InnerModule.T)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.InnerModule.f)))
            @test occursin("(MACROS)", fmt(:(TemplateTests.InnerModule.@m)))

            @test occursin("(TYPES)", fmt(:(TemplateTests.OtherModule.T)))
            @test occursin("(TYPES)", fmt(:(TemplateTests.OtherModule.ISSUE_115)))
            @test occursin("(MACROS)", fmt(:(TemplateTests.OtherModule.@m)))
            @test fmt(:(TemplateTests.OtherModule.f)) == "method `f`\n"
        end
    end
    @testset "Interpolation" begin
        let fmt = expr -> Markdown.plain(eval(:(@doc $expr)))
            @test occursin("f(x)", fmt(:(InterpolationTestModule.f)))
            @test occursin("x + 2", fmt(:(InterpolationTestModule.g)))
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
            let f = ((; a=1) -> ()),
                m = first(methods(f))

                @test DSE.keywords(f, m) == [:a]
            end
            let f = ((; a=1, b=2) -> ()),
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
            let m = first(methods((; a=1) -> ()))
                @test DSE.arguments(m) == Symbol[]
            end
            let m = first(methods((x; a=1, b=2) -> ()))
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
                f = (; a=1) -> (),
                m = first(methods(f))

                @test DSE.printmethod(b, f, m) == "f(; a)"
            end
            let b = Docs.Binding(Main, :f),
                f = (; a=1, b=2) -> (),
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
                f = (; a=1, b=2, c...) -> (),
                m = first(methods(f))
                # Keywords are not ordered, so check for both combinations.
                @test DSE.printmethod(b, f, m) in ("f(; a, b, c...)", "f(; b, a, c...)")
            end
        end
        @testset "getmethods" begin
            @test length(DSE.getmethods(M.f, Union{})) == 1
            @test length(DSE.getmethods(M.f, Tuple{})) == 0
            @test length(DSE.getmethods(M.f, Union{Tuple{},Tuple{Any}})) == 1
            @test length(DSE.getmethods(M.h_3, Tuple{M.A{Int}})) == 1
            @test length(DSE.getmethods(M.h_3, Tuple{Array{Int,3}})) == 1
            @test length(DSE.getmethods(M.h_3, Tuple{Array{Int,1}})) == 0
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
            @test DSE.alltypesigs(Tuple{G} where G) == Any[Tuple{G} where G]
        end
        @testset "groupby" begin
            let groups = DSE.groupby(Int, Vector{Int}, collect(1:10)) do each
                    mod(each, 3), each
                end
                @test groups == Pair{Int,Vector{Int}}[
                    0=>[3, 6, 9],
                    1=>[1, 4, 7, 10],
                    2=>[2, 5, 8],
                ]
            end
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
                "TRAVIS_BUILD_DIR" => dirname(@__DIR__)
            ) do
                @test occursin("github.com/JuliaDocs/NonExistent/tree/<commit>/test/TestModule/M.jl", DSE.url(first(methods(M.f))))
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
