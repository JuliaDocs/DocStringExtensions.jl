
# Don't build docs on version 0.4 since they will fail.
VERSION < v"0.5.0-dev" && exit()

using Documenter, DocStringExtensions

makedocs(
    sitename = "DocStringExtensions.jl",
    modules = [DocStringExtensions],
    format = Documenter.Formats.HTML,
    clean = false,
    pages = Any["Home" => "index.md"],
)

deploydocs(
    target = "build",
    deps = nothing,
    make = nothing,
    repo = "github.com/JuliaDocs/DocStringExtensions.jl.git",
)

