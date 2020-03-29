module ExtensibleEffects
export Continuation, NoEffect, Eff, noeffect, effect, runeffect, runlast, @syntax_eff, @syntax_eff_run

include("core.jl")
include("effecthandler.jl")
include("syntax.jl")
include("instances.jl")

end # module
