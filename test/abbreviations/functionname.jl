@testset "FUNCTIONNAME" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
    @testset "function names" begin
        doc.data = Dict(
            :binding => Docs.Binding(M, :f),
            :typesig => Tuple{Any},
            :module => M,
        )
        str = formatted(DSE.FUNCTIONNAME, doc)
        @test_reference ro_path("function_names.txt") str
    end
end
