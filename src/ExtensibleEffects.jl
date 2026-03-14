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

include("utils.jl")
include("core.jl")
include("effecthandler.jl")
include("outereffecthandler.jl")
include("autorun.jl")
include("syntax.jl")
include("instances.jl")


# Type Inference Workarounds
# --------------------------

# TODO unfortunately this does not work yet for everything
# Cthulhu still tells that inference failed because of recursion

# define recursion_relation so that inference works better
# we probably have problems with true infinite cases now, but that should be still
# better in total

# It is a workaround this issue https://github.com/JuliaLang/julia/issues/45759

recursion_relation_always_true(@nospecialize(_...)) = true

for f in (TypeClasses.flatmap, eff_flatmap, map, Eff)
  for m in methods(f)
    if Base.moduleroot(m.module) === ExtensibleEffects
      m.recursion_relation = recursion_relation_always_true
    end
  end
end

end # module
