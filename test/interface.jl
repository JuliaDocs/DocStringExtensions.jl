@testset "interface" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
        buf = IOBuffer()

        # Errors.
        let result = @test_throws ErrorException DSE.format(nothing, buf, doc)
            @test result.value.msg == "`format` not implemented for `Nothing`."
        end

    @testset "Interpolation" begin
            @test occursin("f(x)", rendered(:(InterpolationTestModule.f)))
            @test occursin("x + 2", rendered(:(InterpolationTestModule.g)))
            @test rendered(:(InterpolationTestModule.Templated.h)) == "h(x)\n\nmethod `h`\n"
            @test rendered(:(InterpolationTestModule.StructOnlyTemplate.k)) == "method `k`\n"
    end
end
