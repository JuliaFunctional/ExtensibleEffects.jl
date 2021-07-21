module ExtensibleEffects
export effect, noeffect, NoEffect,
  runhandlers, @runhandlers,
  @insert_into_runhandlers,
  @syntax_eff, @syntax_eff_noautorun, noautorun,
  WriterHandler,
  ContextManagerHandler, @runcontextmanager, @runcontextmanager_, ContextManagerCombinedHandler,
  CallableHandler, @runcallable,  # Callable handler
  StateHandler, @runstate

using Compat
using Reexport
using TypeClasses

# re-export all DataTypes
@reexport using TypeClasses.DataTypes
@reexport using DataTypesBasic
export @pure  # users need @pure for the monadic syntax @syntax_eff

include("core.jl")
include("effecthandler.jl")
include("outereffecthandler.jl")
include("autorun.jl")
include("syntax.jl")
include("instances.jl")

end # module
