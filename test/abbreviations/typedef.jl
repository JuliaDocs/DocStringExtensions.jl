@testset "TYPEDEF" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
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

    # A type parameter's bound and a supertype written with `<:T` print as written.
    @testset "anonymous type parameters" begin
        names = [:Bounded, :Instance, :Leap, :Extended, :Jittered]
        str = join([[rendered(:(AnonymousTypeVarsTestModule.$name)) for name in names]; rendered(:(AnonymousTypeVarsTestModule.Nested.Leaf))], "\n")
        @test_reference ro_path("typedef_anonymous.txt") str
    end

    # A parameter that `<:T` can't write prints as the alias it came from, in a bound and in a
    # supertype. Before Julia 1.6 `show` separates the supertype's parameters with `,` alone.
    @testset "alias type parameters" begin
        str = join([rendered(:(AnonymousTypeVarsTestModule.$name)) for name in [:Shapes, :SmallV]], "\n")
        @test_reference ro_path(VERSION < v"1.6" ? "typedef_aliases_pre_16.txt" : "typedef_aliases.txt") str
    end
end
