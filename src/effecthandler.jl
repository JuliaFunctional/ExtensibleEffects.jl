abstract type Branch end

struct BranchStart{T} <: Branch
  value::T
end
BranchStart() = BranchStart(())
struct BranchEnd{T} <: Branch
  value::T
end

"""
    runhandlers(handlers, eff)
    runhandlers((Vector, Option), eff)::Vector{Option{...}}

run all handlers such that the first handler will define the most outer container
"""
runhandlers(single_handler, eff::Eff) = runlast_ifpossible(runhandler(single_handler, eff))
runhandlers(all_handlers::Vector, eff::Eff) = runhandlers(tuple(all_handlers...), eff)
runhandlers(all_handlers::Tuple, eff::Eff) = runlast_ifpossible(_runhandlers(all_handlers, eff))
_runhandlers(all_handlers::Tuple{}, eff::Eff) = eff
function _runhandlers(all_handlers::Tuple, eff::Eff)
  subresult = _runhandlers(Base.tail(all_handlers), eff)
  runhandler(first(all_handlers), subresult)
end

runhandlers(any, not_eff) = error("can only apply runhandlers onto an `Eff`, got a ``$(typeof(not_eff))`")

"""
extract final value from Eff with all effects (but Identity) already run
"""
function runlast(eff::Eff)
  final = runhandler(NoEffect, eff) # finally run NoEffect and BranchStart/BranchEnd by running a dummy hanlder NoEffect
  @assert isempty(final.cont) "expected eff without continuation, but found cont=$(final.cont)"
  @assert final.value isa NoEffect "not all effects have been handled, found $(final.value)"
  final.value.value
end

"""
like ``ExtensibleEffects.runlast``, however if the Eff is not yet completely handled, it just returns it.

Note that it applies ``runhandler(Identity, eff)`` and returns this.
"""
function runlast_ifpossible(eff::Eff)
  final = runhandler(NoEffect, eff)  # finally run NoEffect and BranchStart/BranchEnd by running a dummy hanlder NoEffect
  if isempty(final.cont) && final.value isa NoEffect
    final.value.value
  else
    final
  end
end


"""
    runhandler(handler, eff::Eff)
    runhandler(handler, eff::Eff, context)

key method to run an effect on some effecthandler Eff

note that we represent effectrunners as plain types in order to associate
standard effect runners with types like Vector, Option, ...
"""
function runhandler(handler, eff::Eff)
  interpreted_continuation = if isempty(eff.cont)
    Continuation(x -> _eff_pure(handler, x))
  else
    Continuation(x -> runhandler(handler, eff.cont(x)))
  end

  if eff_applies(handler, eff.value)
    _eff_flatmap(handler, interpreted_continuation, eff.value)

  elseif eff.value isa NoEffect
    # NoEffect are directly evaluated so that they can represent the current execution scope
    # otherwise, we would have NoEffect with several continuations, which themselves return NoEffect, which may
    # lead to surprising results due to lazy evaluations of strict semantics
    # this way everything is always executed immediately
    interpreted_continuation(eff.value.value)

  elseif eff.value isa BranchStart
    # as Eff is only linear, pure use of NoEffect would lead to branches beeing merged as soon as everything is NoEffect
    # however we would like to ensure, that a continuation within a branch, does never execute code from a following
    # sister branch
    # Hence we guarantee that there is always BranchEnd effect, until all effects within a branch have been successfully
    # interpreted. Only then a BranchStart meets its BranchEnd and get annilihated,
    innereff = interpreted_continuation(eff.value.value)
    if innereff.value isa BranchEnd
      # if a start found an end, we drop both and just continue
      innereff.cont(innereff.value.value)
    else
      # else we keep the BranchStart
      flatmap(_ -> innereff, Eff(BranchStart()))
    end

  else
    # if we don't know how to handle the current eff, we return it with the new continuation
    # this ensures the handler is applied recursively
    Eff(eff.value, interpreted_continuation)
  end
end



# effecthandler interface
# =======================
# to support an effect, a type needs to implement three functions
# 1. eff_flatmap
# 2. eff_pure
# 3. eff_applies

# eff_flatmap
# -----------

function _eff_flatmap(handler, interpreted_continuation::Continuation, value)
  # Core.println("ENTER handler = $handler, objectid(value) = $(objectid(value)), value = $value")
  # provide convenience wrapper if someone forgets to return an Eff
  result = eff_flatmap(handler, interpreted_continuation, value)
  # Core.println("EXIT  handler = $handler, objectid(value) = $(objectid(value)), value = $value")
  isa(result, Eff) ? result : noeffect(result)
end

"""
    ExtensibleEffects.eff_flatmap(handler, interpreted_continuation, value)
    ExtensibleEffects.eff_flatmap(interpreted_continuation, value)

Overwrite this for your custom effect handler to handle your effect.
This function is only called if ``eff_applies(handler, value)==true``.

While for custom effects it is handy to dispatch on the handler itself, in simple cases
`handler == typeof(value)` and hence, we allow to ommit it.

Parameters
----------
The arg `interpreted_continuation` is guaranteed to return an Eff of the handled type.
E.g. if you might handle the type ``Vector``, you are guaranteed that `interpreted_continuation(x)::Eff{Vector}`

Return
------
If you do not return an ``Eff``, the result will be wrapped into `noeffect` automatically,
i.e. assuming the effect is handled afterwards.
"""
eff_flatmap(handler, interpreted_continuation, value) = eff_flatmap(interpreted_continuation, value)


# eff_pure
# --------

function _eff_pure(handler, value)
  result = eff_pure(handler, value)
  isa(result, Eff) ? result : noeffect(result)
end

"""
    ExtensibleEffects.eff_pure(handler, value)

Overwrite this for your custom effect handler, return either EffType or a plain value.
Plain values will be wrapped with `noeffect` automatically.
"""
function eff_pure end


# eff_applies
# -----------

"""
    ExtensibleEffects.eff_applies(handler::YourHandlerType, value::ToBeHandledEffectType) = true

Overwrite this function like above to indicate that a concrete effect is handled by a handler.
In most cases you will have ``YourHandlerType = Type{ToBeHandledEffectType}``, like for ``Vector`` or similar.

Sometimes you need extra information without which you cannot run a specific effect. Then you need to link
the specific handler containing the required information. E.g. `Callable` needs `args` and `kwargs` to be run,
which are captured in the handler type `CallableHandler(args, kwargs)`.
Hence above you would choose YourHandlerType = `CallableHandler`, and ToBeHandledEffectType = `Callable`.
"""
eff_applies(handler, value) = false
