immutable Require
    name::String
    lower_bound::Nullable{VersionNumber}
    upper_bound::Nullable{VersionNumber}
    platform::Nullable{String}
end

immutable Version
    version::VersionNumber
    sha1::String
    requires::Array{Require,1}

    function Version(version, sha1)
        new(version, sha1, Require[])
    end
end

immutable Package
    name::String
    url::String
    owner::Nullable{String}
    versions::Array{Version,1}

    function Package(name, url, owner)
        new(name, url, owner, Version[])
    end
end


function pkgdb()
    loc = Pkg.dir()

    const GHURL = r"^(?:git@|git://|https://(?:[\w\.\+\-]+@)?)github.com[:/](([^/].+)/(.+?))(?:\.git)?$"i

    pkgs_data = Package[]

    for pkg in readdir(joinpath(loc, "METADATA"))
        pkgdir = joinpath(loc, "METADATA", pkg)

        (!isdir(pkgdir) || pkg == ".git" || pkg == ".test") && continue

        if isfile(joinpath(pkgdir, "url"))
            url = readchomp(joinpath(pkgdir, "url"))
        else
            warn("$pkg will be omitted from the database: does not have a URL")
            continue
        end

        if !isdir(joinpath(pkgdir, "versions"))
            warn("$pkg will be omitted from the database: no available versions")
            continue
        end

        pkg_data = Package(pkg, url, ismatch(GHURL, url) ? Nullable{String}(match(GHURL, url).captures[2]) : Nullable{String}())
        push!(pkgs_data, pkg_data)

        for ver in readdir(joinpath(pkgdir, "versions"))
            verdir = joinpath(pkgdir, "versions", ver)

            if isfile(joinpath(verdir, "sha1"))
                sha = readchomp(joinpath(verdir, "sha1"))
            else
                warn("$pkg version $ver will be omitted: no corresponding SHA-1")
                continue
            end

            version_data = Version(ver, sha)
            push!(pkg_data.versions, version_data)

            if isfile(joinpath(verdir, "requires"))
                lines = map(chomp, readlines(joinpath(verdir, "requires")))
                filter!(s -> !isempty(s) && !all(isspace, s), lines)

                for req in lines
                    m = match(r"^(@\w+\s+)?(\w+)(\s+[\d.-]+)?(\s+[\d.-]+)?", req)
                    m === nothing && continue

                    plt, dep, lb, ub = m.captures

                    require_data = Require(dep, lb === nothing ? Nullable{VersionNumber}() : lstrip(lb), ub === nothing ? Nullable{VersionNumber}() : lstrip(ub), plt === nothing ? Nullable{String}() : rstrip(plt)[2:end])
                    push!(version_data.requires, require_data)
                end
            end
        end
    end

    return pkgs_data
end
