module ExtensibleEffects
export Eff, Continuation,
  effect, noeffect,
  runhandlers, @runhandlers,
  @insert_into_runhandlers,
  autorun,
  @syntax_eff, @syntax_eff_noautorun,
  WriterHandler,
  ContextManagerHandler, @runcontextmanager, @runcontextmanager_,
  CallableHandler, @runcallable,  # Callable handler
  StateHandler, @runstate

include("core.jl")
include("effecthandler.jl")
include("outereffecthandler.jl")
include("autorun.jl")
include("syntax.jl")
include("instances.jl")

end # module
