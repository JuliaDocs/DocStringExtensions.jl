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
end
