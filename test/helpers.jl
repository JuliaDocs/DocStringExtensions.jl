# initialize a test repo in test/fixtures/TestModule which is needed for some tests
function with_test_repo(f)
    repo = LibGit2.init(joinpath(@__DIR__, "fixtures", "TestModule"))
    LibGit2.add!(repo, "M.jl")
    sig = LibGit2.Signature("zeptodoctor", "zeptodoctor@zeptodoctor.com", round(time()), 0)
    LibGit2.commit(repo, "M.jl", committer=sig, author=sig)
    LibGit2.GitRemote(repo, "origin", "https://github.com/JuliaDocs/NonExistent.jl.git")
    try
        f()
    finally
        rm(joinpath(@__DIR__, "fixtures", "TestModule", ".git"); force=true, recursive=true)
    end
end

# The docstring on `Param{T}() where {T}`, which records where it was written.
function param_constructor_doc()
    local multidoc = Docs.meta(M)[Docs.Binding(M, :Param)]
    return multidoc.docs[first(filter(sig -> sig != Union{}, multidoc.order))]
end

# `with_test_repo` commits afresh each run and the checkout location differs per machine,
# so the commit hash and the local path in METHODLIST output are redacted.
# Two `replace` calls because `replace(s, pairs...)` is missing on older Julia.
function redact_local_info(str)
    str = replace(str, r"(defined at \[`).+?(test[/\\]fixtures[/\\]TestModule)" => s"\1[...]\2")
    return replace(str, r"(tree/).+(/M)" => s"\1[...]\2")
end

module_imports_reference() =
    ro_path(VERSION < v"1.12" ? "module_imports_pre_112.txt" : "module_imports_112_and_after.txt")
method_lists_reference(name = "method_lists") =
    ro_path(name * (Sys.iswindows() ? "_windows.txt" : "_nonwindows.txt"))
# Julia 1.6 lists the methods that a default argument generates in the opposite order.
typed_method_lists_reference(name) =
    method_lists_reference(VERSION >= v"1.6" && VERSION < v"1.7" ? name * "_16" : name)
definition_arguments_with_defaults(expr) = DSE.definition_arguments(expr, true)

# The first part of `ex`, depth first, that `f` accepts, or `nothing`.
function find_expression(f, ex)
    f(ex) && return ex
    ex isa Expr || return nothing
    for arg in ex.args
        local found = find_expression(f, arg)
        found === nothing || return found
    end
    return nothing
end
typed_signatures_h_reference() =
    ro_path(typeof(1) === Int64 ? "typed_method_signatures_64bit.txt" : "typed_method_signatures_32bit.txt")
