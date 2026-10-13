@testset "README and LICENSE" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
        @testset "README/LICENSE" begin
            doc.data = Dict(:module => DocStringExtensions)
            str = formatted(DSE.README, doc)
            @test_reference ro_path("readme.txt") str
            str = formatted(DSE.LICENSE, doc)
            @test_reference ro_path("license.txt") str
        end
end
