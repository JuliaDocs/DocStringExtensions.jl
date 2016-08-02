
# Don't build docs on version 0.4 since they will fail.
VERSION < v"0.5.0-dev" && exit()

using Documenter, DocStringExtensions

makedocs(
    modules = [DocStringExtensions],
    clean = false,
)

deploydocs(
    deps = Deps.pip("pygments", "mkdocs", "mkdocs-material"),
    repo = "github.com/JuliaDocs/DocStringExtensions.jl.git",
)

