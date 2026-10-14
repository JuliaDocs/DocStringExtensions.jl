@testset "settings" begin
    unset = ("DOCSTRINGEXTENSIONS_RETURN_ARROW" => nothing, "DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH" => nothing)
    withenv(unset...) do
        @test DSE.return_arrow() == "->"
        @test DSE.signature_width() == 60
    end
    withenv("DOCSTRINGEXTENSIONS_RETURN_ARROW" => "→", "DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH" => "92") do
        @test DSE.return_arrow() == "→"
        @test DSE.signature_width() == 92
    end
    # An empty value leaves the default.
    withenv("DOCSTRINGEXTENSIONS_RETURN_ARROW" => "", "DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH" => "") do
        @test DSE.return_arrow() == "->"
        @test DSE.signature_width() == 60
    end
    # A width that is not a positive integer warns and leaves the default.
    for value in ("wide", "0")
        withenv("DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH" => value) do
            message = "`DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH` must be a positive integer, got \"$value\". Using 60."
            @test (@test_logs (:warn, message) DSE.signature_width()) == 60
        end
    end

    let b = Docs.Binding(M, :T),
            f = M.T,
            m = first(methods(f))

        withenv("DOCSTRINGEXTENSIONS_RETURN_ARROW" => "→") do
            typed = DSE.printmethod(IOBuffer(), b, f, m, DSE.argsig(m); returns = "M.T")
            @test String(take!(typed)) == "T(a, b, c) → M.T"
        end
        withenv("DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH" => "8") do
            @test DSE.printmethod(b, f, m) == "T(\n    a,\n    b,\n    c\n)"
        end
    end
end
