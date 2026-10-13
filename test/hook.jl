@testset "hook" begin
        # A template resolves when its docstring is defined, so the stored docstring keeps no
        # `Template`, and with it no documented expression. A binding that does not exist yet
        # keeps its `Template` until the docstring is displayed.
        templates(mod, name) = [part
            for docstr in values(Docs.meta(mod)[Docs.Binding(mod, name)].docs)
            for part in docstr.text if part isa DSE.Template]
        @test isempty(templates(TemplateTests, :f))
        @test isempty(templates(TemplateTests, :S))
        @test isempty(templates(TemplateTests, :Inner))
        @test isempty(templates(TemplateTests, :Paired))
        # A module's docstring is kept in the module itself.
        let docstr = Docs.meta(TemplateTests.Documented)[Docs.Binding(TemplateTests, :Documented)].docs[Union{}]
            @test !any(part -> part isa DSE.Template, docstr.text)
        end
        @test isempty(templates(TemplateTests.InnerModule, :T))
        @test isempty(templates(InterpolationTestModule.Templated, :h))
        @test !isempty(templates(TemplateTests, :early))
        @test all(part -> part.expr == :(early(x)), templates(TemplateTests, :early))
        # Forwarding replaces the `Docs.doc!` call and leaves the documented definition as it is.
        let find = find_expression,
            definition(ex) = Meta.isexpr(ex, :(=)) && ex.args[1] == :(walked(x)),
            calling(callee) = ex -> Meta.isexpr(ex, :call) && ex.args[1] === callee,
            out = Docs.docm(LineNumberNode(1), TemplateTests, "docs", :(walked(x) = x)),
            forwarded = DSE.forward_doc_calls(out)

            @test find(definition, forwarded) === find(definition, out)
            @test find(calling(Docs.doc!), forwarded) === nothing
            @test find(calling(DSE.forward_doc!), forwarded) !== nothing
            @test find(calling(Docs.doc!), out) !== nothing
        end
        # A precompile directive whose signature no longer matches compiles nothing.
        @test all(((f, types),) -> precompile(f, types), DSE.PRECOMPILED)
        # The resolved template keeps the definition's arguments in place of the expression.
        let parts = [part
                for docstr in values(Docs.meta(DefaultsTestModule.Templated)[Docs.Binding(DefaultsTestModule.Templated, :templated)].docs)
                for part in docstr.text]
            @test any(part -> part isa DSE.MethodSignatures && part.definition !== nothing, parts)
        end
end
