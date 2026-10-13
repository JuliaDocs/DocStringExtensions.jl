@testset "interface" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
        buf = IOBuffer()

        # Errors.
        let result = @test_throws ErrorException DSE.format(nothing, buf, doc)
            @test result.value.msg == "`format` not implemented for `Nothing`."
        end

    @testset "Interpolation" begin
        let fmt = expr -> Markdown.plain(eval(:(@doc $expr)))
            @test occursin("f(x)", fmt(:(InterpolationTestModule.f)))
            @test occursin("x + 2", fmt(:(InterpolationTestModule.g)))
            @test fmt(:(InterpolationTestModule.Templated.h)) == "h(x)\n\nmethod `h`\n"
            @test fmt(:(InterpolationTestModule.StructOnlyTemplate.k)) == "method `k`\n"
        end
    end
end
