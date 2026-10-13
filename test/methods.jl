@testset "methods" begin
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
        @test DSE.arguments(first(methods(M.T))) == ["a", "b", "c"]
        # Inference only matters from Julia 1.10.
        VERSION >= v"1.10" && @test @inferred(DSE.arguments(first(methods(M.T)))) isa Vector{String}
        @test DSE.arguments(first(methods(M.K))) == String[]
        @test DSE.arguments(first(methods(M.f))) == ["x"]
        let m = first(methods(() -> ()))
            @test DSE.arguments(m) == String[]
        end
        let m = first(methods((a) -> ()))
            @test DSE.arguments(m) == ["a"]
        end
        let m = first(methods((; a = 1) -> ()))
            @test DSE.arguments(m) == String[]
        end
        let m = first(methods((x; a = 1, b = 2) -> ()))
            @test DSE.arguments(m) == ["x"]
        end
        let m = first(methods((; a...) -> ()))
            @test DSE.arguments(m) == String[]
        end
        # Methods generated for positional defaults name unnamed arguments differently.
        @test DSE.arguments(which(M.k_4, Tuple{String})) == ["_"]
        let m = first(methods(((a, b), c) -> c))
            @test DSE.arguments(m) == ["_", "c"]
        end
    end

    @testset "return types" begin
        @test Base.return_types(DSE.argsig, (Method,)) == [Type]
        @test Base.return_types(DSE.get_method_source, (Method,)) == [Core.CodeInfo]
        @test Base.return_types(DSE.method_return_type, (Function, Method, Type)) == [Vector{Any}]
    end

    @testset "tuple_parameters" begin
        @test collect(@inferred(DSE.tuple_parameters(Tuple{Int, String}))) == [Int, String]
        @test DSE.tuple_parameters(Tuple{T, Int} where {T})[2] == Int
        @test_throws TypeError DSE.tuple_parameters(Union{Tuple{Int}, Tuple{String}})
    end

    # The documented callable tells a constructor written with parameters from one called
    # through an alias. `Curve{Linear}(x)` and `LinearCurve(x)` define the same method.
    @testset "constructor_parameters" begin
        A = AliasesTestModule
        explicit = which(A.Arr{Int, 2}, (Tuple,))
        @test string.(DSE.constructor_parameters(A.Arr, explicit)) == ["T", "2"]
        @test DSE.constructor_parameters(A.Mat, which(A.Mat, (Matrix{Int},))) === nothing
        @test DSE.constructor_parameters(A.LTM, which(A.LTM, (Ref{Int},))) === nothing
        # Parameters written through an alias are the alias's own, not the type's.
        @test DSE.constructor_parameters(A.Mat, which(A.Mat{Int}, (Matrix{Int},))) == [Int]
        @test DSE.constructor_parameters(A.IMat, which(A.IMat, (Ref{Int},))) === nothing
        curve = which(A.Curve{A.Linear}, (Real,))
        @test DSE.constructor_parameters(A.Curve, curve) == [A.Linear]
        @test DSE.constructor_parameters(A.LinearCurve, curve) === nothing
    end

    @testset "getmethods" begin
        @test length(DSE.getmethods(M.f, Union{})) == 1
        @test length(DSE.getmethods(M.f, Tuple{})) == 0
        @test length(DSE.getmethods(M.f, Union{Tuple{}, Tuple{Any}})) == 1
        @test length(DSE.getmethods(M.h_3, Tuple{M.A{Int}})) == 1
        @test length(DSE.getmethods(M.h_3, Tuple{Array{Int, 3}})) == 1
        @test length(DSE.getmethods(M.h_3, Tuple{Array{Int, 1}})) == 0
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
        let typesig = Union{Tuple{}, Tuple{Any, Vararg{Any}}}
            @test length(DSE.methodgroups(M.k_13, typesig, M)) == 1
            @test length(DSE.methodgroups(M.k_13, typesig, M)[1]) == 2
        end
        # The docsystem's typesig for `k_21(x::T = 1, xs::T...) where {T}` on Julia 1.12
        # and later, which subtyping cannot prove equal to the union of the methods.
        let typesig = Union{Tuple{T}, Tuple{Vararg{T}}} where {T}
            @test length(DSE.methodgroups(M.k_21, typesig, M)) == 1
            @test length(DSE.methodgroups(M.k_21, typesig, M)[1]) == 2
        end
        # Both `k_14` methods share a line, and `Union{Tuple{Any},Tuple{Int}} == Tuple{Any}`.
        @test length(DSE.methodgroups(M.k_14, Tuple{Any}, M)[1]) == 1
    end

    @testset "signatures_equal" begin
        defaults = (x = 1, y = 2, zs...) -> x
        @test DSE.signatures_equal(collect(methods(defaults)), Tuple)
        @test !DSE.signatures_equal(collect(methods((x::Integer) -> x)), Tuple{Any})
        # A vararg typesig takes more arguments than any fixed method.
        fixed = collect(methods((x = 1, y = 2) -> x))
        @test !DSE.signatures_equal(fixed, Tuple)
        @test DSE.signatures_equal(fixed, Union{Tuple{}, Tuple{Any}, Tuple{Any, Any}})
    end

    @testset "alltypesigs" begin
        @test DSE.alltypesigs(Union{}) == Any[]
        @test DSE.alltypesigs(Union{Tuple{}}) == Any[Tuple{}]
        @test DSE.alltypesigs(Tuple{}) == Any[Tuple{}]
        @test DSE.alltypesigs(Tuple{G} where {G}) == Any[Tuple{G} where {G}]
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

    @testset "comparemethods" begin
        let f = first(methods(M.f)),
                g = first(methods(M.g))

            @test !DSE.comparemethods(f, f)
            @test DSE.comparemethods(f, g)
            @test !DSE.comparemethods(g, f)
        end
    end
end
