using DDMFramework
using Documenter

DocMeta.setdocmeta!(DDMFramework, :DocTestSetup, :(using DDMFramework); recursive=true)

makedocs(;
    modules=[DDMFramework],
    authors="Johannes Ahnlide <johannes@voxel.se> and contributors",
    repo="https://github.com/ahnlabb/DDMFramework.jl/blob/{commit}{path}#{line}",
    sitename="DDMFramework.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://ahnlabb.github.io/DDMFramework.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/ahnlabb/DDMFramework.jl",
    devbranch="main",
)
