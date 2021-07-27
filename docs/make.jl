using ExtensibleEffects
using Documenter

DocMeta.setdocmeta!(ExtensibleEffects, :DocTestSetup, :(using ExtensibleEffects); recursive=true)

makedocs(;
    modules=[ExtensibleEffects],
    authors="Stephan Sahm <stephan.sahm@gmx.de> and contributors",
    repo="https://github.com/JuliaFunctional/ExtensibleEffects.jl/blob/{commit}{path}#{line}",
    sitename="ExtensibleEffects.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JuliaFunctional.github.io/ExtensibleEffects.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Manual" => [
            "Introduction" => "manual-introduction.md",
            "Effects" => "manual-effects.md",
            "How it works" => "manual-how-it-works.md",
            "JuliaCon 2021" => "manual-juliacon.md",
        ],
        "Library" => "library.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaFunctional/ExtensibleEffects.jl",
    devbranch="main",
)
