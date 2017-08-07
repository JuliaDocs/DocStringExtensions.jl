
# Don't build docs on version 0.4 since they will fail.

using Documenter, DocStringExtensions

makedocs(
    sitename = "DocStringExtensions.jl",
    modules = [DocStringExtensions],
    format = :html,
    clean = false,
    pages = Any["Home" => "index.md"],
)

deploydocs(
    target = "build",
    deps = nothing,
    make = nothing,
    repo = "github.com/JuliaDocs/DocStringExtensions.jl.git",
)

