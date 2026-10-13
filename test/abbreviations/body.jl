@testset "BODY" begin
    @testset "function bodies" begin
        names = [:logit, :clamped, :nested, :wrapped]
        str = join([rendered(:(BodyTestModule.$name)) for name in names], "\n")
        @test_reference ro_path("function_bodies.txt") str
        # Base prints a nested quote as `$(Expr(:quote, ...))` before Julia 1.6.
        if VERSION >= v"1.6"
            @test rendered(:(BodyTestModule.quoted)) == "```julia\n:(x + \$x)\n```\n"
        end
        @test isempty(rendered(:(BodyTestModule.emptybody)))
        @test isempty(rendered(:(BodyTestModule.nomethods)))
        @test isempty(rendered(:(BodyTestModule.NotAMethod)))
        @test rendered(:(BodyTestModule.Templated.templated)) ==
            "```julia\nx + 1\n```\n\nmethod `templated`\n"
    end
end
