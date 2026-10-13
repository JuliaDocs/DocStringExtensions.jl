@testset "SIGNATURES" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
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
            :typesig => Union{Tuple{}, Tuple{Any}},
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
            :typesig => Union{Tuple{}, Tuple{Any}, Tuple{Any, Any}, Tuple{Any, Any, Any}},
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
            :typesig => Union{Tuple{Any, Int, Any}},
            :module => M,
        )
        str = formatted(SIGNATURES, doc)
        @test_reference ro_path(typeof(1) === Int64 ? "signatures_union_tuple_int_any_64bit.txt" : "signatures_union_tuple_int_any_32bit.txt") str

        # `Param{T}() where {T}` is a method of `Type{Param{T}}`, and its typesig also
        # holds a `Tuple{T}` that matches the default constructor `Param(a::T)`. The
        # docstring's location picks out the documented definition.
        str = formatted(SIGNATURES, param_constructor_doc())
        @test_reference ro_path("signatures_parametric_constructor.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :l_1),
            :typesig => Tuple{String},
            :module => M,
        )
        str = formatted(DSE.MethodSignatures(returns = true), doc)
        @test_reference ro_path("signatures_returns_inferred.txt") str
        str = formatted(DSE.MethodSignatures(returns = "success::Bool"), doc)
        @test_reference ro_path("signatures_returns_text.txt") str
        str = formatted(DSE.TypedMethodSignatures(returns = "success::Bool"), doc)
        @test_reference ro_path("typed_signatures_returns_text.txt") str

        # The text follows each method that a positional default generates.
        doc.data = Dict(
            :binding => Docs.Binding(M, :l_1),
            :typesig => Union{Tuple{Symbol}, Tuple{Symbol, Bool}},
            :module => M,
        )
        str = formatted(DSE.MethodSignatures(returns = "success::Bool"), doc)
        @test_reference ro_path("signatures_returns_text_defaults.txt") str
        str = formatted(DSE.TypedMethodSignatures(returns = "success::Bool"), doc)
        @test_reference ro_path("typed_signatures_returns_text_defaults.txt") str
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
        # Julia 1.14 infers a type-valued result as `Core.TypeEgal{T}`.
        if VERSION >= v"1.14.0-DEV"
            @test_reference ro_path("typed_method_signatures_tuple_string_114_and_later.txt") str
        else
            @test_reference ro_path("typed_method_signatures_tuple_string_pre_114.txt") str
        end

        doc.data = Dict(
            :binding => Docs.Binding(M, :h),
            :typesig => Tuple{Int, Int, Int},
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
            :typesig => Tuple{T} where {T},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k0.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :k_1),
            :typesig => Union{Tuple{String}, Tuple{String, T}, Tuple{String, T, T}, Tuple{T}} where {T <: Number},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k1.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :k_2),
            :typesig => (Union{Tuple{String, U, T}, Tuple{T}, Tuple{U}} where {T <: Number}) where {U <: Complex},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k2.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :k_3),
            :typesig => (Union{Tuple{Any, T, U}, Tuple{U}, Tuple{T}} where {U <: Any}) where {T <: Any},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k3.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :k_4),
            :typesig => Union{Tuple{String}, Tuple{String, Int}},
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
            :typesig => Union{Tuple{Type{T}, String}, Tuple{Type{T}, String, Union{Nothing, Function}}, Tuple{T}} where {T <: Number},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k5.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :k_6),
            :typesig => Union{Tuple{Vector{T}}, Tuple{T}} where {T <: Number},
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
            :typesig => Union{Tuple{Union{Nothing, T}}, Tuple{T}, Tuple{Union{Nothing, T}, T}} where {T <: Integer},
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
            :typesig => Union{Tuple{T where {T}}},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k9.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :k_11),
            :typesig => Union{Tuple{Int, Vararg{Any}}},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k11.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :k_12),
            :typesig => Union{Tuple{Int, Vararg{Real}}},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k12.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :k_15),
            :typesig => Tuple{T, Vararg{T}} where {T <: Number},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k15.txt") str

        # Julia expands `xs::Vararg{T,n}` in a signature into `n` arguments of type `T`.
        doc.data = Dict(
            :binding => Docs.Binding(M, :k_16),
            :typesig => Tuple{Real, Vararg{Int, 2}},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k16.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :k_17),
            :typesig => Union{Tuple{Vararg{T, 2}}, Tuple{T}} where {T <: Integer},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k17.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :k_18),
            :typesig => Tuple{Int},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k18.txt") str

        # The return type belongs to the documented method, not to a more specific one
        # whose signature overlaps it.
        doc.data = Dict(
            :binding => Docs.Binding(M, :overlapping),
            :typesig => Tuple{Integer},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_overlapping.txt") str

        # Julia 1.12 and later normalise this typesig to `Tuple`, which matches neither
        # method's arity.
        doc.data = Dict(
            :binding => Docs.Binding(M, :k_13),
            :typesig => Union{Tuple{}, Tuple{Any, Vararg{Any}}},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_normalised.txt") str

        # Julia 1.12 and later build this typesig for `k_21(x::T = 1, xs::T...) where {T}`.
        doc.data = Dict(
            :binding => Docs.Binding(M, :k_21),
            :typesig => Union{Tuple{T}, Tuple{Vararg{T}}} where {T},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k21.txt") str

        # A lower bound puts a second tuple of the same arity into the typesig.
        doc.data = Dict(
            :binding => Docs.Binding(M, :k_22),
            :typesig => Union{Tuple{Int8}, Tuple{T}} where {Int8 <: T <: Integer},
            :module => M,
        )
        str = formatted(DSE.TYPEDSIGNATURES, doc)
        @test_reference ro_path("typed_method_signatures_k22.txt") str

        str = formatted(DSE.TYPEDSIGNATURES, param_constructor_doc())
        @test_reference ro_path("typed_method_signatures_parametric_constructor.txt") str
    end

    @testset "method signatures with types (no return type)" begin
        doc.data = Dict(
            :binding => Docs.Binding(M, :h_1),
            :typesig => Tuple{M.A},
            :module => M,
        )
        str = formatted(DSE.TypedMethodSignatures(returns = false), doc)
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
        str = formatted(DSE.TypedMethodSignatures(returns = false), doc)
        @test_reference ro_path("typed_method_signatures_no_return_g2.txt") str

        doc.data = Dict(
            :binding => Docs.Binding(M, :h),
            :typesig => Tuple{Int, Int, Int},
            :module => M,
        )
        str = formatted(DSE.TypedMethodSignatures(returns = false), doc)
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
        str = formatted(DSE.TypedMethodSignatures(returns = false), doc)
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

    @testset "signature defaults" begin
        names = [:positional, :keywords, :typed, :parametric, :unnamed, :wrapped, :nospecialized, :destructured, :varargs]
        str = join([rendered(:(DefaultsTestModule.$name)) for name in names], "\n")
        @test_reference ro_path("signature_defaults.txt") str
        @test rendered(:(DefaultsTestModule.Templated.templated)) ==
            "```julia\ntemplated(x, y=1)\n```\n\nmethod `templated`\n"
        names = [:bracketed, :typed_bracketed, :unnamed_bracketed, :varargs_bracketed]
        str = join([rendered(:(DefaultsTestModule.$name)) for name in names], "\n")
        @test_reference ro_path("signature_defaults_brackets.txt") str
        @test_throws ArgumentError DSE.MethodSignatures(defaults = :bracket)
        @test_throws ArgumentError DSE.TypedMethodSignatures(defaults = :Brackets)
    end

    @testset "constructor signatures" begin
        names = [:Plain, :Typed, :Parametric, :Inner, :Options, :TypedOptions, :EmptyOptions, :Wrapped, :Generated, :Empty]
        str = join([rendered(:(ConstructorsTestModule.$name)) for name in names], "\n")
        @test_reference ro_path("constructor_signatures.txt") str
        @test isempty(rendered(:(ConstructorsTestModule.Abstract)))
        @test rendered(:(ConstructorsTestModule.Templated.Point)) ==
            "```julia\nPoint(x)\n```\n\ntype `Point`\n"
    end

    # A method of another definition whose signature only falls inside the typesig is left out.
    @testset "other definitions" begin
        names = [:D, :E, Symbol("@mac")]
        str = join([rendered(:(OtherDefinitionsTestModule.$name)) for name in names], "\n")
        @test_reference ro_path("signatures_other_definitions.txt") str
    end

    # A constructor called through an alias prints as the alias, without the parameters the
    # alias fixes. One written with its parameters keeps them.
    @testset "alias constructors" begin
        names = [:Mat, :IMat, :LTM, :Curve]
        str = join([rendered(:(AliasesTestModule.$name)) for name in names], "\n")
        @test_reference ro_path("signatures_alias_constructors.txt") str
    end

    # `D{T}(g)` for a type with more parameters than the call writes leaves the rest free.
    @testset "partial parameter constructors" begin
        names = [:D, :F]
        str = join([rendered(:(PartialParametersTestModule.$name)) for name in names], "\n")
        @test_reference ro_path("signatures_partial_parameter_constructors.txt") str
    end

    # A callable method of a type's instances prints as the call on an instance, and not as a
    # constructor of the type that takes as many arguments.
    @testset "callable signatures" begin
        names = [:Scale, :Zero, :Entrainment, :Reconstruct, :Weighted]
        str = join([rendered(:(CallablesTestModule.$name)) for name in names], "\n")
        # Before Julia 1.9 the docsystem files `(e::Entrainment{NF})(σ, τ::NF)` under `e`.
        if VERSION >= v"1.9"
            @test_reference ro_path("signatures_callables_19_and_later.txt") str
        else
            @test_reference ro_path("signatures_callables_pre_19.txt") str
        end
    end

    # A callable on `Type{<:T}` is filed under `Type`, so it prints the instance type.
    @testset "Type callable signatures" begin
        multidoc = Docs.meta(CallablesTestModule)[Docs.Binding(Core, :Type)]
        str = join([Markdown.plain(Docs.parsedoc(multidoc.docs[sig])) for sig in multidoc.order], "\n")
        @test_reference ro_path("signatures_type_callables.txt") str
    end

    @testset "signature destructuring" begin
        names = [:pair, :typed, :nested, :unshowable]
        str = join([rendered(:(DestructuringTestModule.$name)) for name in names], "\n")
        @test_reference ro_path("signature_destructuring.txt") str
        @test rendered(:(DestructuringTestModule.Templated.templated)) ==
            "```julia\ntemplated((x, y))\n```\n\nmethod `templated`\n"
    end

    @testset "printed_typesig" begin
        f = (x::Integer, y) -> x
        m = first(methods(f))
        @test DSE.printed_typesig(f, m, Any[Tuple{Int}, Tuple{Integer, Any}]) == Tuple{Integer, Any}
        @test DSE.printed_typesig(f, m, Any[Tuple{Int}, Tuple{Int, Int}]) == Tuple{Int, Int}
        @test DSE.printed_typesig(f, m, Any[Tuple{T, T} where {T}]) == (Tuple{T, T} where {T})
        @test DSE.printed_typesig(f, m, Any[Tuple{Int}]) == Tuple{Integer, Any}
        # An expanded vararg and a parametric constructor keep their own signature.
        g = (xs::Vararg{Int, 2}) -> xs
        expanded = first(methods(g))
        @test DSE.printed_typesig(g, expanded, Any[Tuple{Any, Any}]) == Tuple{Int, Int}
        constructor = first(methods(M.Param2{Int}, Tuple{Any}))
        @test DSE.printed_typesig(M.Param2, constructor, Any[Tuple{Any}]) == DSE.argsig(constructor)
    end

    @testset "has_arity" begin
        @test DSE.has_arity(Tuple{Int, Int}, 2)
        @test DSE.has_arity(Tuple{T, T} where {T}, 2)
        @test !DSE.has_arity(Tuple{Int}, 2)
        @test !DSE.has_arity(Int, 1)
    end
end
