module DocStringExtensionsLibGit2Ext

import DocStringExtensions
import LibGit2

function DocStringExtensions.url(mod::Module, file::AbstractString, line::Integer)
    file = Sys.iswindows() ? replace(file, '\\' => '/') : file
    if Base.inbase(mod) && !isabspath(file)
        local base = "https://github.com/JuliaLang/julia/tree"
        if isempty(Base.GIT_VERSION_INFO.commit)
            return "$base/v$VERSION/base/$file#L$line"
        else
            local commit = Base.GIT_VERSION_INFO.commit
            return "$base/$commit/base/$file#L$line"
        end
    else
        if isfile(file)
            local d = dirname(file)
            try # might not be in a git repo
                LibGit2.with(LibGit2.GitRepoExt(d)) do repo
                    LibGit2.with(LibGit2.GitConfig(repo)) do cfg
                        local u = LibGit2.get(cfg, "remote.origin.url", "")
                        local m = match(LibGit2.GITHUB_REGEX, u)
                        u = m === nothing ? get(ENV, "TRAVIS_REPO_SLUG", "") : m.captures[1]
                        local commit = string(LibGit2.head_oid(repo))
                        local root = LibGit2.path(repo)
                        if startswith(file, root) || startswith(realpath(file), root)
                            local base = "https://github.com/$u/tree"
                            local filename = file[(length(root) + 1):end]
                            return "$base/$commit/$filename#L$line"
                        else
                            return ""
                        end
                    end
                end
            catch err
                isa(err, LibGit2.GitError) || rethrow()
                return ""
            end
        else
            return ""
        end
    end
end

end