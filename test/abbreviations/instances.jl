@testset "INSTANCES" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
    @testset "enum instances" begin
        doc.data = Dict(:binding => Docs.Binding(M, :Color), :typesig => Union{})
        @test_reference ro_path("enum_instances.txt") formatted(INSTANCES, doc)

        doc.data = Dict(:binding => Docs.Binding(M, :Fruit), :typesig => Union{})
        @test_reference ro_path("enumx_instances.txt") formatted(INSTANCES, doc)

        doc.data = Dict(:binding => Docs.Binding(M, :T), :typesig => Union{})
        @test formatted(INSTANCES, doc) == ""
    end

    @testset "enum_entries" begin
        @test DSE.enum_entries(M.Color) isa Vector{Tuple{String, String}}
        @test DSE.enum_entries(M.Fruit) isa Vector{Tuple{String, String}}
        @test DSE.enum_entries(M.T) isa Vector{Tuple{String, String}}
    end
end
