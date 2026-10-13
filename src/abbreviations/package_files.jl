"""
The singleton type for [`README`](@ref) abbreviations.
"""
struct Readme <: Abbreviation end

"""
An [`Abbreviation`](@ref) that includes the package README: the first file in the package
root whose name contains `readme`, in any case. It prints nothing for a module that is not
part of a package.

!!! note
    The file is parsed as [Julia Markdown](https://docs.julialang.org/en/v1/stdlib/Markdown/),
    which differs from GitHub Markdown. For example, `[text][]` link shortcuts are not
    supported.
"""
const README = Readme()

"""
The singleton type for [`LICENSE`](@ref) abbreviations.
"""
struct License <: Abbreviation end

"""
An [`Abbreviation`](@ref) that includes the package license: the first file in the package
root whose name contains `license`, in any case. It prints nothing for a module that is not
part of a package.

!!! note
    The file is parsed as [Julia Markdown](https://docs.julialang.org/en/v1/stdlib/Markdown/),
    which differs from GitHub Markdown. For example, `[text][]` link shortcuts are not
    supported.
"""
const LICENSE = License()

function format(::T, buf, doc) where {T <: Union{Readme, License}}
    m = get(doc.data, :module, nothing)
    m === nothing && return
    path = pathof(m)
    path === nothing && return
    return try # wrap in try/catch since we shouldn't error in case some IO operation goes wrong
        r = T === Readme ? r"(?i)readme(?-i)" : r"(?i)license(?-i)"
        # assume README/LICENSE is located in the root of the repo
        root = normpath(joinpath(path, "..", ".."))
        for file in readdir(root)
            if occursin(r, file)
                str = read(joinpath(root, file), String)
                write(buf, str)
                return
            end
        end
    catch
    end
end
