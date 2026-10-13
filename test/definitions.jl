@testset "definitions" begin
        @testset "definition_arguments" begin
            let d = definition_arguments_with_defaults(:(f(x, y = 1, z::String = "z"; a = :a, b::Int = 2, c, d...) = x))
                @test d.positional == [("x", nothing), ("y", "1"), ("z", "\"z\"")]
                @test d.keywords == Dict("a" => ":a", "b" => "2")
            end
            @test definition_arguments_with_defaults(:(function f(x = zero(T)) where {T} end)).positional == [("x", "zero(T)")]
            @test definition_arguments_with_defaults(:(f(x = 1)::Int = x)).positional == [("x", "1")]
            @test definition_arguments_with_defaults(:(@inline f(x = nothing) = x)).positional == [("x", "nothing")]
            @test definition_arguments_with_defaults(:(f(::Int = 0, xs...) = 0)).positional == [("_", "0"), ("xs", nothing)]
            @test definition_arguments_with_defaults(:(f((a, b), c = 1) = c)).positional == [("(a, b)", nothing), ("c", "1")]
            @test definition_arguments_with_defaults(:(f((a, b)::Tuple) = a)).positional == [("(a, b)", nothing)]
            @test definition_arguments_with_defaults(:(struct S x end)) === nothing
            @test definition_arguments_with_defaults(:(function f end)) === nothing
            @test definition_arguments_with_defaults(:(const C = 1)) === nothing
            @test definition_arguments_with_defaults(:(@enum Color red blue)) === nothing
            @test DSE.definition_body(:(@enum Color red blue)) === nothing
            # Without defaults, only a destructured argument changes what a signature prints.
            @test DSE.definition_arguments(:(f(x, y = 1; k = 2) = x), false) === nothing
            let d = DSE.definition_arguments(:(f((a, b), y = 1; k = 2) = a), false)
                @test d.positional == [("(a, b)", nothing), ("y", nothing)]
                @test isempty(d.keywords)
            end
            let (_, default) = definition_arguments_with_defaults(:(f(w = x -> x + 1) = w)).positional[1]
                @test !occursin("#=", default)
            end
            let d = definition_arguments_with_defaults(:(f(x = @m(1); k = g(@m(2))) = x))
                @test !occursin("#=", d.positional[1][2])
                @test !occursin("#=", d.keywords["k"])
            end
        end

        @testset "field_defaults" begin
            @test DSE.field_defaults(:(Base.@kwdef struct S
                "Documented."
                a::Int = 1
                b = [1, 2]
                c::Float64
                d = @m(a)
                S(a, b, c, d) = new(a, b, c, d)
                S(a::T) where {T} = new(a, [], 0.0, nothing)
            end)) == Dict(:a => "1", :b => "[1, 2]", :d => "@m(a)")
            # StructUtils.jl writes field tags after the default.
            @test DSE.field_defaults(:(@defaults struct S
                a::String = "x" & (json = (name = "y",),)
                b::Int & (name = "z",)
                c = x & y
            end)) == Dict(:a => "\"x\"", :c => "x & y")
            # Parameters.jl allows assertions in the body.
            @test DSE.field_defaults(:(@with_kw struct S
                a = 1
                @assert a > 0
            end)) == Dict(:a => "1")
            # Configurations.jl takes an alias before the struct.
            @test DSE.field_defaults(:(@option "alias" struct S
                a::Int = 1
            end)) == Dict(:a => "1")
            # `const` fields parse only from Julia 1.8.
            let body = Expr(:block, Expr(:const, :(a::Int = 1)))
                @test DSE.field_defaults(Expr(:struct, true, :S, body)) == Dict(:a => "1")
            end
            # Fields in a nested block, and an `@atomic` field.
            let atomic = Expr(:(=), Expr(:macrocall, Symbol("@atomic"), nothing, :(a::Int)), 1),
                body = Expr(:block, atomic, Expr(:block, :(b = 2)))

                @test DSE.field_defaults(Expr(:struct, true, :S, body)) == Dict(:a => "1", :b => "2")
            end
            @test DSE.field_defaults(:(Base.@kwdef struct S
                a = "use `f` here"
                b = begin
                    x + 1
                end
            end)) == Dict(:a => "\"use `f` here\"", :b => "begin\n    x + 1\nend")
            @test DSE.field_defaults(:(struct S a::Int end)) === nothing
            @test DSE.field_defaults(:(@enum Color red blue)) === nothing
            @test DSE.field_defaults(:(f(x = 1) = x)) === nothing
        end
end
