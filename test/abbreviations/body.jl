@testset "BODY" begin
    @testset "function bodies" begin
        let fmt = expr -> Markdown.plain(eval(:(@doc $expr)))
            names = [:logit, :clamped, :nested, :wrapped]
            str = join([fmt(:(BodyTestModule.$name)) for name in names], "\n")
            @test_reference ro_path("function_bodies.txt") str
            # Base prints a nested quote as `$(Expr(:quote, ...))` before Julia 1.6.
            if VERSION >= v"1.6"
                @test fmt(:(BodyTestModule.quoted)) == "```julia\n:(x + \$x)\n```\n"
            end
            @test isempty(fmt(:(BodyTestModule.emptybody)))
            @test isempty(fmt(:(BodyTestModule.nomethods)))
            @test isempty(fmt(:(BodyTestModule.NotAMethod)))
            @test fmt(:(BodyTestModule.Templated.templated)) ==
                "```julia\nx + 1\n```\n\nmethod `templated`\n"
        end
    end
end
