module ExtensibleEffects
export Continuation, NoEffect, Eff, noeffect, effect, runhandlers, runhandler, runlast, autorun, @syntax_eff

include("core.jl")
include("effecthandler.jl")
include("autorun.jl")
include("syntax.jl")
include("instances.jl")

end # module
