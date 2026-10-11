# Add docs/lib to LOAD_PATH so that we could load the Examples module like a library.
let doclib = abspath(joinpath(@__DIR__, "Examples", "src"))
    doclib in LOAD_PATH || pushfirst!(LOAD_PATH, doclib)
end

using Documenter, DocStringExtensions
import Markdown
import Examples

# Called from `@eval` blocks in `examples/*.md` to print an example file above its docstrings.
example_source(file) =
    Markdown.MD(Markdown.Code("julia", read(joinpath(@__DIR__, "Examples", "src", file), String)))

DocMeta.setdocmeta!(DocStringExtensions, :DocTestSetup, :(using DocStringExtensions); recursive = true)

const TOPICS = ["functions", "types", "enums", "modules", "templates"]

makedocs(
    sitename = "DocStringExtensions.jl",
    modules = [DocStringExtensions, Examples],
    clean = false,
    pages = Any[
        "Home" => "index.md",
        "Setup" => "setup.md",
        "Examples" => ["examples/$topic.md" for topic in TOPICS],
        "Reference" => ["reference/$topic.md" for topic in TOPICS],
        "Internals" => "internals.md",
    ],
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
    ),
)

deploydocs(
    repo = "github.com/JuliaDocs/DocStringExtensions.jl.git",
    push_preview = true,
)
