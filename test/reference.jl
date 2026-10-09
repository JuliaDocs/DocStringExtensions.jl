const UPDATE_REFERENCES = get(ENV, "DSE_UPDATE_REFERENCES", "false") == "true"

ro_path(fn) = joinpath(@__DIR__, "reference_outputs", fn)

formatted(abbr, doc) = sprint(io -> DocStringExtensions.format(abbr, io, doc))

# CRLF is stripped from both sides so references match under Windows `autocrlf` checkouts.
function matches_reference(path, actual)
    actual = replace(actual, "\r" => "")
    if UPDATE_REFERENCES
        write(path, actual)
        return true
    end
    expected = replace(read(path, String), "\r" => "")
    expected == actual && return true
    @error string(
        "Output does not match `$path`. Rerun with `DSE_UPDATE_REFERENCES=true` to rewrite it.\n",
        "Lines marked `-` are in the reference only, `+` in the actual output only.\n",
        sprint(show, DeepDiffs.deepdiff(expected, actual); context = stderr),
    )
    return false
end

macro test_reference(path, actual)
    check = :(matches_reference($(esc(path)), $(esc(actual))))
    return Expr(:macrocall, Symbol("@test"), __source__, check)
end
