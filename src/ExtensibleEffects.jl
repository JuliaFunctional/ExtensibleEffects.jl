module ExtensibleEffects
export Eff, Continuation,
  effect, noeffect, NoEffect,
  runhandlers, @runhandlers,
  @insert_into_runhandlers,
  @syntax_eff, @syntax_eff_noautorun, noautorun,
  WriterHandler,
  ContextManagerHandler, @runcontextmanager, @runcontextmanager_, ContextManagerCombinedHandler,
  CallableHandler, @runcallable,  # Callable handler
  StateHandler, @runstate

include("core.jl")
include("effecthandler.jl")
include("outereffecthandler.jl")
include("autorun.jl")
include("syntax.jl")
include("instances.jl")

end # module
