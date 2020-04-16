module ExtensibleEffects
export Continuation, Eff, NoEffect,
  effect, noeffect,
  runhandlers, @runhandlers,
  autorun,
  @syntax_eff

include("core.jl")
include("effecthandler.jl")
include("autorun.jl")
include("syntax.jl")
include("instances.jl")

end # module
