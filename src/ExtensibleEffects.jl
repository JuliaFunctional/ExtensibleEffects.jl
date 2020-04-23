module ExtensibleEffects
export Continuation, Eff, NoEffect,
  effect, noeffect,
  runhandlers, @runhandlers,
  @insert_into_runhandlers,
  autorun,
  @syntax_eff, @syntax_eff_noautorun,
  WriterHandler,
  CallableHandler, @runcallable,  # Callable handler
  StateHandler, @runstate

include("core.jl")
include("effecthandler.jl")
include("outereffecthandler.jl")
include("autorun.jl")
include("syntax.jl")
include("instances.jl")

end # module
