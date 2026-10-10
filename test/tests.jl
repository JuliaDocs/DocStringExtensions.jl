const DSE = DocStringExtensions

include("templates.jl")
include("interpolation.jl")
include("defaults.jl")
include("TestModule/M.jl")
# `public` is a syntax error before Julia 1.11.
VERSION >= v"1.11" && include("public.jl")

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

# `with_test_repo` commits afresh each run and the checkout location differs per machine,
# so the commit hash and the local path in METHODLIST output are redacted.
# Two `replace` calls because `replace(s, pairs...)` is missing on older Julia.
function redact_local_info(str)
    str = replace(str, r"(defined at \[`).+?(test[/\\]TestModule)" => s"\1[...]\2")
    return replace(str, r"(tree/).+(/M)" => s"\1[...]\2")
end

module_imports_reference() =
    ro_path(VERSION < v"1.12" ? "module_imports_pre_112.txt" : "module_imports_112_and_after.txt")
method_lists_reference(name = "method_lists") =
    ro_path(name * (Sys.iswindows() ? "_windows.txt" : "_nonwindows.txt"))
# Julia 1.6 lists the methods that a default argument generates in the opposite order.
typed_method_lists_reference(name) =
    method_lists_reference(VERSION >= v"1.6" && VERSION < v"1.7" ? name * "_16" : name)
typed_signatures_h_reference() =
    ro_path(typeof(1) === Int64 ? "typed_method_signatures_64bit.txt" : "typed_method_signatures_32bit.txt")

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

        # How `Docs.docm` registers a docstring.
        #
        # Used in src/templates.jl by forward_doc_calls(), which replaces each call to the
        # `Docs.doc!` function object, and by the template_hook() method for the `@doc` calls
        # that `@__doc__` leaves to be expanded later. forward_doc!() takes the same arguments:
        # a signature, or none for a module.
        let calls(f, ex) = ex isa Expr ? Int(f(ex)) + reduce(+, Int[calls(f, arg) for arg in ex.args]; init = 0) : 0,
            doc_call(ex) = Meta.isexpr(ex, :call) && ex.args[1] === Docs.doc!,
            doc_call_with(nargs) = ex -> doc_call(ex) && length(ex.args) == nargs + 1,
            doc_macro(ex) = Meta.isexpr(ex, :macrocall) && ex.args[1] === Symbol("@doc"),
            docm(ex) = Docs.docm(LineNumberNode(1), @__MODULE__, "docs", ex)

            @test calls(doc_call_with(4), docm(:(f(x) = x))) == 1
            @test calls(doc_call_with(3), docm(:(module DocmModule end))) == 1
            @test calls(doc_call, docm(:((f, g)))) == 2
            let out = docm(:(Base.@kwdef struct DocmStruct end)),
                arity = VERSION < v"1.6" ? 5 : 7

                @test calls(doc_call, out) == 0
                @test calls(ex -> doc_macro(ex) && length(ex.args) == arity, out) == 1
            end
        end

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

        # Whether a method's last positional argument is a vararg.
        #
        # Used in src/utilities.jl for the untyped printmethod() method.
        @test first(methods(M.k_11)).isva
        @test !first(methods(M.f)).isva

        # Whether a name is exported, since `names` also returns `public` names on 1.11+.
        #
        # Used in src/abbreviations.jl for the EXPORTS abbreviation.
        @test Base.isexported(M, :f)
        @test !Base.isexported(M, :g_1)

        # Whether a method is `@generated`.
        #
        # Used in src/utilities.jl for the typed printmethod() method. Julia before 1.10 has
        # no `Base.hasgenerator`, and the `hasgenerator` shim reads the `generator` field.
        @test DSE.hasgenerator(first(methods(M.g_1)))
        @test !DSE.hasgenerator(first(methods(M.f)))

        # Rendering default values as source text.
        #
        # Used in src/utilities.jl for the argument_defaults() function.
        @test sprint(Base.show_unquoted, :(zero(T))) == "zero(T)"
        @test sprint(Base.show_unquoted, :x) == "x"
        @test sprint(Base.show_unquoted, "x") == "\"x\""
        @test sprint(Base.show_unquoted, QuoteNode(:x)) == ":x"
        @test Base.remove_linenums!(Expr(:block, LineNumberNode(1), :x)) == Expr(:block, :x)
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
            str = formatted(IMPORTS, doc)
            @test_reference module_imports_reference() str

            # Module exports.
            str = formatted(EXPORTS, doc)
            @test_reference ro_path("module_exports.txt") str

            # Module public names, which are only the exports in a module without `public`.
            str = formatted(PUBLIC, doc)
            @test_reference ro_path("module_exports.txt") str

            # Issue 190: `public` names are public but not exported.
            if VERSION >= v"1.11"
                doc.data = Dict(
                    :binding => Docs.Binding(Main, :PublicNames),
                    :typesig => Union{},
                )
                str = formatted(EXPORTS, doc)
                @test_reference ro_path("module_exports_with_public.txt") str
                str = formatted(PUBLIC, doc)
                @test_reference ro_path("module_public.txt") str
            end
        end

        @testset "type fields" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :T),
                :fields => Dict(
                    :a => "one",
                    :b => "two",
                ),
            )
            str = formatted(FIELDS, doc)
            @test_reference ro_path("fields.txt") str

            str = formatted(TYPEDFIELDS, doc)
            @test_reference ro_path("typed_fields.txt") str
        end

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
            installed = "defined at [`packages/DocStringExtensions/Ab1Cd/test/TestModule/M.jl:5`" * url
            @test redact_local_info(installed) ==
                "defined at [`[...]test/TestModule/M.jl:5`](https://github.com/JuliaDocs/NonExistent.jl/tree/[...]/M.jl#L5)."
            windows = "defined at [`C:\\Users\\u\\.julia\\dev\\DocStringExtensions\\test\\TestModule\\M.jl:5`" * url
            @test redact_local_info(windows) ==
                "defined at [`[...]test\\TestModule\\M.jl:5`](https://github.com/JuliaDocs/NonExistent.jl/tree/[...]/M.jl#L5)."
        end

        @testset "method lists with types" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :l_1),
                :typesig => Union{},
                :module => M,
            )
            str = with_test_repo(() -> formatted(TYPEDMETHODLIST, doc))
            @test_reference typed_method_lists_reference("typed_method_lists") redact_local_info(str)

            str = with_test_repo(() -> formatted(DSE.TypedMethodList(false), doc))
            @test_reference typed_method_lists_reference("typed_method_lists_no_return") redact_local_info(str)
        end

        @testset "method signatures" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :f),
                :typesig => Tuple{Any},
                :module => M,
            )
            str = formatted(SIGNATURES, doc)
            @test_reference ro_path("method_signatures.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :g),
                :typesig => Union{Tuple{},Tuple{Any}},
                :module => M,
            )
            str = formatted(SIGNATURES, doc)
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
            str = formatted(SIGNATURES, doc)
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
            str = formatted(SIGNATURES, doc)
            @test_reference ro_path("signatures_tuple_any.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :h_4),
                :typesig => Union{Tuple{Any,Int,Any}},
                :module => M,
            )
            str = formatted(SIGNATURES, doc)
            @test_reference ro_path("signatures_union_tuple_int_any.txt") str
        end

        @testset "method signatures with types" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :h_1),
                :typesig => Tuple{M.A},
                :module => M,
            )
            str = formatted(DSE.TYPEDSIGNATURES, doc)
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
            str = formatted(DSE.TYPEDSIGNATURES, doc)
            @test_reference ro_path("typed_method_signatures_tuple_string.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :h),
                :typesig => Tuple{Int,Int,Int},
                :module => M,
            )
            str = formatted(DSE.TYPEDSIGNATURES, doc)
            @test_reference typed_signatures_h_reference() str

            doc.data = Dict(
                :binding => Docs.Binding(M, :h),
                :typesig => Tuple{Int},
                :module => M,
            )
            str = formatted(DSE.TYPEDSIGNATURES, doc)
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
            str = formatted(DSE.TYPEDSIGNATURES, doc)
            @test_reference ro_path("typed_method_signatures_k0.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_1),
                :typesig => Union{Tuple{String},Tuple{String,T},Tuple{String,T,T},Tuple{T}} where T<:Number,
                :module => M,
            )
            str = formatted(DSE.TYPEDSIGNATURES, doc)
            @test_reference ro_path("typed_method_signatures_k1.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_2),
                :typesig => (Union{Tuple{String,U,T},Tuple{T},Tuple{U}} where T<:Number) where U<:Complex,
                :module => M,
            )
            str = formatted(DSE.TYPEDSIGNATURES, doc)
            @test_reference ro_path("typed_method_signatures_k2.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_3),
                :typesig => (Union{Tuple{Any,T,U},Tuple{U},Tuple{T}} where U<:Any) where T<:Any,
                :module => M,
            )
            str = formatted(DSE.TYPEDSIGNATURES, doc)
            @test_reference ro_path("typed_method_signatures_k3.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_4),
                :typesig => Union{Tuple{String},Tuple{String,Int}},
                :module => M,
            )
            str = formatted(DSE.TYPEDSIGNATURES, doc)
            if typeof(1) === Int64
                @test_reference ro_path("typed_method_signatures_k4_64bit.txt") str
            else
                @test_reference ro_path("typed_method_signatures_k4_32bit.txt") str
            end

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_5),
                :typesig => Union{Tuple{Type{T},String},Tuple{Type{T},String,Union{Nothing,Function}},Tuple{T}} where T<:Number,
                :module => M,
            )
            str = formatted(DSE.TYPEDSIGNATURES, doc)
            @test_reference ro_path("typed_method_signatures_k5.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_6),
                :typesig => Union{Tuple{Vector{T}},Tuple{T}} where T<:Number,
                :module => M,
            )
            str = formatted(DSE.TYPEDSIGNATURES, doc)
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
            str = formatted(DSE.TYPEDSIGNATURES, doc)
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
            str = formatted(DSE.TYPEDSIGNATURES, doc)
            @test_reference ro_path("typed_method_signatures_k8.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :k_9),
                :typesig => Union{Tuple{T where T}},
                :module => M,
            )
            str = formatted(DSE.TYPEDSIGNATURES, doc)
            @test_reference ro_path("typed_method_signatures_k9.txt") str

            @static if VERSION > v"1.5-" # see JuliaLang/#40405

                doc.data = Dict(
                    :binding => Docs.Binding(M, :k_11),
                    :typesig => Union{Tuple{Int,Vararg{Any}}},
                    :module => M,
                )
                str = formatted(DSE.TYPEDSIGNATURES, doc)
                @test_reference ro_path("typed_method_signatures_k11.txt") str

                doc.data = Dict(
                    :binding => Docs.Binding(M, :k_12),
                    :typesig => Union{Tuple{Int,Vararg{Real}}},
                    :module => M,
                )
                str = formatted(DSE.TYPEDSIGNATURES, doc)
                @test_reference ro_path("typed_method_signatures_k12.txt") str
            end


        end

        @testset "method signatures with types (no return type)" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :h_1),
                :typesig => Tuple{M.A},
                :module => M,
            )
            str = formatted(DSE.TypedMethodSignatures(false), doc)
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
            str = formatted(DSE.TypedMethodSignatures(false), doc)
            @test_reference ro_path("typed_method_signatures_no_return_g2.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :h),
                :typesig => Tuple{Int,Int,Int},
                :module => M,
            )
            str = formatted(DSE.TypedMethodSignatures(false), doc)
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
            str = formatted(DSE.TypedMethodSignatures(false), doc)
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
            str = formatted(DSE.FUNCTIONNAME, doc)
            @test_reference ro_path("function_names.txt") str
        end

        @testset "type definitions" begin
            doc.data = Dict(
                :binding => Docs.Binding(M, :AbstractType1),
                :typesig => Union{},
                :module => M,
            )
            str = formatted(DSE.TYPEDEF, doc)
            @test_reference ro_path("typedef1.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :AbstractType2),
                :typesig => Union{},
                :module => M,
            )
            str = formatted(DSE.TYPEDEF, doc)
            @test_reference ro_path("typedef2.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :CustomType),
                :typesig => Union{},
                :module => M,
            )
            str = formatted(DSE.TYPEDEF, doc)
            @test_reference ro_path("typedef_custom.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :BitType8),
                :typesig => Union{},
                :module => M,
            )
            str = formatted(DSE.TYPEDEF, doc)
            @test_reference ro_path("typedef_bittype8.txt") str

            doc.data = Dict(
                :binding => Docs.Binding(M, :BitType32),
                :typesig => Union{},
                :module => M,
            )
            str = formatted(DSE.TYPEDEF, doc)
            @test_reference ro_path("typedef_bittype32.txt") str
        end

        @testset "enum instances" begin
            doc.data = Dict(:binding => Docs.Binding(M, :Color), :typesig => Union{})
            @test_reference ro_path("enum_instances.txt") formatted(INSTANCES, doc)

            doc.data = Dict(:binding => Docs.Binding(M, :Fruit), :typesig => Union{})
            @test_reference ro_path("enumx_instances.txt") formatted(INSTANCES, doc)

            doc.data = Dict(:binding => Docs.Binding(M, :T), :typesig => Union{})
            @test formatted(INSTANCES, doc) == ""
        end

        @testset "README/LICENSE" begin
            doc.data = Dict(:module => DocStringExtensions)
            str = formatted(DSE.README, doc)
            @test_reference ro_path("readme.txt") str
            str = formatted(DSE.LICENSE, doc)
            @test_reference ro_path("license.txt") str
        end
    end
    @testset "templates" begin
        let fmt = expr -> Markdown.plain(eval(:(@doc $expr)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.K)))
            @test occursin("(TYPES)", fmt(:(TemplateTests.T)))
            @test length(collect(eachmatch(r"\(TYPES\)", fmt(:(TemplateTests.S))))) == 1
            @test occursin("(TYPES)", fmt(:(TemplateTests.ISSUE_115)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.f)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.g)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.h)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.@m)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.r)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.early)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.Inner)))
            # `@doc` returns the binding before Julia 1.13 and the documented value from 1.13.
            doc_value(v) = v isa Docs.Binding ? (:binding, v.var) : (:value, nameof(v))
            @test doc_value(TemplateTests.DOC_VALUE) == doc_value(Untemplated.DOC_VALUE)
            @test fmt(:(TemplateTests.LateTemplate.before)) == "method `before`\n"
            @test fmt(:(TemplateTests.LateTemplate.after)) == "(LATE)\n\nmethod `after`\n"
            # Bindings documented together each get the template for their own category.
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.paired)))
            @test occursin("(TYPES)", fmt(:(TemplateTests.Paired)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.Documented)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.Redocumented)))

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
        # A template resolves when its docstring is defined, so the stored docstring keeps no
        # `Template`, and with it no documented expression. A binding that does not exist yet
        # keeps its `Template` until the docstring is displayed.
        templates(mod, name) = [part
            for docstr in values(Docs.meta(mod)[Docs.Binding(mod, name)].docs)
            for part in docstr.text if part isa DSE.Template]
        @test isempty(templates(TemplateTests, :f))
        @test isempty(templates(TemplateTests, :S))
        @test isempty(templates(TemplateTests, :Inner))
        @test isempty(templates(TemplateTests, :Paired))
        # A module's docstring is kept in the module itself.
        let docstr = Docs.meta(TemplateTests.Documented)[Docs.Binding(TemplateTests, :Documented)].docs[Union{}]
            @test !any(part -> part isa DSE.Template, docstr.text)
        end
        @test isempty(templates(TemplateTests.InnerModule, :T))
        @test isempty(templates(InterpolationTestModule.Templated, :h))
        @test !isempty(templates(TemplateTests, :early))
        @test all(part -> part.expr == :(early(x)), templates(TemplateTests, :early))
        # Issue 151: a template without `DOCSTRING` is rejected where it is defined.
        for template in ("test", Expr(:string, "test ", :SIGNATURES))
            mod = Module()
            Core.eval(mod, :(using DocStringExtensions))
            @test_throws ArgumentError Core.eval(mod, :(@template DEFAULT = $template))
        end
    end
    @testset "Interpolation" begin
        let fmt = expr -> Markdown.plain(eval(:(@doc $expr)))
            @test occursin("f(x)", fmt(:(InterpolationTestModule.f)))
            @test occursin("x + 2", fmt(:(InterpolationTestModule.g)))
            @test fmt(:(InterpolationTestModule.Templated.h)) == "h(x)\n\nmethod `h`\n"
            @test fmt(:(InterpolationTestModule.StructOnlyTemplate.k)) == "method `k`\n"
        end
    end
    @testset "signature defaults" begin
        let fmt = expr -> Markdown.plain(eval(:(@doc $expr)))
            names = [:positional, :keywords, :typed, :parametric, :unnamed, :wrapped, :nospecialized, :destructured, :varargs]
            str = join([fmt(:(DefaultsTestModule.$name)) for name in names], "\n")
            @test_reference ro_path("signature_defaults.txt") str
            @test fmt(:(DefaultsTestModule.Templated.templated)) ==
                "```julia\ntemplated(x, y=1)\n\n```\n\nmethod `templated`\n"
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
            # Methods generated for positional defaults name unnamed arguments differently.
            @test DSE.arguments(which(M.k_4, Tuple{String})) == ["_"]
            let m = first(methods(((a, b), c) -> c))
                @test DSE.arguments(m) == ["_", :c]
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
            let b = Docs.Binding(Main, :f),
                f = (x, ::String) -> x,
                m = first(methods(f))

                @test DSE.printmethod(b, f, m) == "f(x, _)"
                typed = DSE.printmethod(IOBuffer(), b, f, m, Tuple{Any,String}; print_return_types = false)
                @test String(take!(typed)) == "f(x, ::String)"
            end
            let b = Docs.Binding(M, :k_11),
                f = M.k_11,
                m = first(methods(f))

                @test DSE.printmethod(b, f, m) == "k_11(x, xs...)"
            end
            let b = Docs.Binding(M, :f),
                f = M.f,
                m = first(methods(f))

                @test DSE.printmethod(b, f, m) == "f(x)"
            end
            let b = Docs.Binding(M, :g_1),
                f = M.g_1,
                m = first(methods(f))

                # Issue 157: inference cannot run a generator on abstract argument types.
                typed = DSE.printmethod(IOBuffer(), b, f, m, Tuple{Any})
                @test String(take!(typed)) == "g_1(x)"
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
        @testset "argument_defaults" begin
            let d = DSE.argument_defaults(:(f(x, y = 1, z::String = "z"; a = :a, b::Int = 2, c, d...) = x))
                @test d.positional == [(:x, nothing), (:y, "1"), (:z, "\"z\"")]
                @test d.keywords == Dict(:a => ":a", :b => "2")
            end
            @test DSE.argument_defaults(:(function f(x = zero(T)) where {T} end)).positional == [(:x, "zero(T)")]
            @test DSE.argument_defaults(:(f(x = 1)::Int = x)).positional == [(:x, "1")]
            @test DSE.argument_defaults(:(@inline f(x = nothing) = x)).positional == [(:x, "nothing")]
            @test DSE.argument_defaults(:(f(::Int = 0, xs...) = 0)).positional == [(nothing, "0"), (:xs, nothing)]
            @test DSE.argument_defaults(:(f((a, b), c = 1) = c)).positional == [(nothing, nothing), (:c, "1")]
            @test DSE.argument_defaults(:(struct S x end)) === nothing
            @test DSE.argument_defaults(:(function f end)) === nothing
            @test DSE.argument_defaults(:(const C = 1)) === nothing
            let (_, default) = DSE.argument_defaults(:(f(w = x -> x + 1) = w)).positional[1]
                @test !occursin("#=", default)
            end
        end
        @testset "append_defaults" begin
            let d = DSE.argument_defaults(:(g(x = 1, y = 2, z = 3; kwargs...) = x)),
                m = which(M.g, Tuple{Any})

                @test DSE.append_defaults(["x"], ["kwargs..."], m, d) == (["x=1"], ["kwargs..."])
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
            # The docsystem's typesig for `k_13(x = 1, xs...)`, which Julia 1.12 and later
            # normalise to `Tuple`.
            let typesig = Union{Tuple{},Tuple{Any,Vararg{Any}}}
                @test length(DSE.methodgroups(M.k_13, typesig, M)) == 1
                @test length(DSE.methodgroups(M.k_13, typesig, M)[1]) == 2
            end
            # Both `k_14` methods share a line, and `Union{Tuple{Any},Tuple{Int}} == Tuple{Any}`.
            @test length(DSE.methodgroups(M.k_14, Tuple{Any}, M)[1]) == 1
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
    @testset "world-age safety" begin
        # Test that formatting works correctly when called from a stale world age,
        # which is the scenario that triggers failures on Julia 1.12+ with binding
        # partitions. We use invokelatest in the test to simulate the world-age gap
        # that occurs when docstrings are formatted during macro expansion.
        # Each case reuses the reference of the matching `format` testset above.
        latest(abbr, doc) = Base.invokelatest(formatted, abbr, doc)
        doc = Docs.DocStr(Core.svec(), nothing, Dict())

        doc.data = Dict(
            :binding => Docs.Binding(M, :h),
            :typesig => Tuple{Int, Int, Int},
            :module => M,
        )
        @test_reference typed_signatures_h_reference() latest(DSE.TYPEDSIGNATURES, doc)

        doc.data = Dict(
            :binding => Docs.Binding(M, :f),
            :typesig => Tuple{Any},
            :module => M,
        )
        @test_reference ro_path("method_signatures.txt") latest(DSE.SIGNATURES, doc)
        str = with_test_repo(() -> latest(DSE.METHODLIST, doc))
        @test_reference method_lists_reference() redact_local_info(str)

        doc.data = Dict(
            :binding => Docs.Binding(M, :l_1),
            :typesig => Union{},
            :module => M,
        )
        str = with_test_repo(() -> latest(DSE.TYPEDMETHODLIST, doc))
        @test_reference typed_method_lists_reference("typed_method_lists") redact_local_info(str)

        doc.data = Dict(
            :binding => Docs.Binding(M, :T),
            :fields => Dict(:a => "one", :b => "two"),
        )
        @test_reference ro_path("fields.txt") latest(DSE.FIELDS, doc)

        doc.data = Dict(
            :binding => Docs.Binding(M, :AbstractType1),
            :typesig => Union{},
            :module => M,
        )
        @test_reference ro_path("typedef1.txt") latest(DSE.TYPEDEF, doc)

        doc.data = Dict(
            :binding => Docs.Binding(Main, :M),
            :typesig => Union{},
        )
        @test_reference ro_path("module_exports.txt") latest(DSE.EXPORTS, doc)
        @test_reference ro_path("module_exports.txt") latest(DSE.PUBLIC, doc)
        @test_reference module_imports_reference() latest(DSE.IMPORTS, doc)

        doc.data = Dict(:binding => Docs.Binding(M, :Color), :typesig => Union{})
        @test_reference ro_path("enum_instances.txt") latest(DSE.INSTANCES, doc)
        doc.data = Dict(:binding => Docs.Binding(M, :Fruit), :typesig => Union{})
        @test_reference ro_path("enumx_instances.txt") latest(DSE.INSTANCES, doc)
    end
end

DSE.parsedocs(DSE)
