module ExtensibleEffects
export Continuation, Eff, NoEffect,
  effect, noeffect,
  runhandlers, @runhandlers,
  autorun,
  @syntax_eff, @syntax_eff_noautorun,
  CallWith  # Callable handler

include("core.jl")
include("effecthandler.jl")
include("autorun.jl")
include("syntax.jl")
include("instances.jl")

end # module
