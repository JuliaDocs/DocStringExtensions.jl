using DocStringExtensions
using Base.Test

VERSION < v"0.5.0-dev" ? warn("Untestable on Julia 0.4.") : include("tests.jl")

