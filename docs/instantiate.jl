# Documenter depends on DocStringExtensions, so the docs build against a clone of the latest
# Documenter, whose compat bound is widened when it does not cover this version yet.
using Pkg, TOML

const DOCUMENTER_URL = "https://github.com/JuliaDocs/Documenter.jl"
const CLONE = joinpath(@__DIR__, "deps", "Documenter")

version = VersionNumber(TOML.parsefile(joinpath(dirname(@__DIR__), "Project.toml"))["version"])
allowed = Pkg.Versions.semver_spec(TOML.parsefile(joinpath(@__DIR__, "Project.toml"))["compat"]["Documenter"])
tags = read(`git ls-remote --tags $DOCUMENTER_URL`, String)
latest = maximum(v for v in (VersionNumber(m[1]) for m in eachmatch(r"refs/tags/v(\d+\.\d+\.\d+)$"m, tags)) if v in allowed)

rm(CLONE; force = true, recursive = true)
run(`git clone --quiet --depth 1 --branch v$latest $DOCUMENTER_URL $CLONE`)
project_file = joinpath(CLONE, "Project.toml")
project = TOML.parsefile(project_file)
bound = project["compat"]["DocStringExtensions"]
if !(version in Pkg.Versions.semver_spec(bound))
    @info "Documenter v$latest allows DocStringExtensions $bound, widening it to allow v$version"
    project["compat"]["DocStringExtensions"] = "$bound, $(version.major == 0 ? "0.$(version.minor)" : version.major)"
    open(io -> TOML.print(io, project), project_file, "w")
end
Pkg.instantiate()
