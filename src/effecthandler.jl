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

runhandlers(any, not_eff) = error("can only apply runhandlers onto an `Eff`, got a `$(typeof(not_eff))`")

"""
    runlast(eff::Eff)

extract final value from Eff with all effects (but Identity) already run
"""
function runlast(final::Eff)
  @assert isempty(final.cont) "expected eff without continuation, but found cont=$(final.cont)"
  @assert final.value isa NoEffect "not all effects have been handled, found $(final.value)"
  final.value.value
end

"""
    runlast_ifpossible(eff::Eff)

like `ExtensibleEffects.runlast`, however if the Eff is not yet completely handled, it just returns it.
"""
function runlast_ifpossible(final::Eff)
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
  else
    # if we don't know how to handle the current eff, we return it with the new continuation
    # this ensures the handler is applied recursively
    Eff(eff.value, interpreted_continuation)
  end
end


"""
    @runhandlers handlers eff

For convenience we provide `runhandlers` function also as a macro.

With this you can easier run left-over handlers from an `@syntax_eff` autorun.

Example
-------
```
@runhandlers WithCall(args, kwargs) @syntax_eff begin
  a = Callable(x -> 2x)
  @pure a
end
```
"""
macro runhandlers(handlers, eff)
  esc(:(ExtensibleEffects.runhandlers($handlers, $eff)))
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
  # provide convenience wrapper if someone forgets to return an Eff
  result = eff_flatmap(handler, interpreted_continuation, value)
  noeffect(result)
end

"""
    ExtensibleEffects.eff_flatmap(handler, interpreted_continuation, value)
    ExtensibleEffects.eff_flatmap(interpreted_continuation, value)

Overwrite this for your custom effect handler to handle your effect.
This function is only called if `eff_applies(handler, value)==true`.

While for custom effects it is handy to dispatch on the handler itself, in simple cases
`handler == typeof(value)` and hence, we allow to ommit it.

Parameters
----------
The arg `interpreted_continuation` is guaranteed to return an Eff of the handled type.
E.g. if you might handle the type `Vector`, you are guaranteed that `interpreted_continuation(x)::ExtensibleEffects.Eff{Vector}`

Return
------
If you do not return an `ExtensibleEffects.Eff`, the result will be wrapped into `noeffect` automatically,
i.e. assuming the effect is handled afterwards.
"""
eff_flatmap(handler, interpreted_continuation, value) = eff_flatmap(interpreted_continuation, value)


# eff_pure
# --------

function _eff_pure(handler, value)
  result = eff_pure(handler, value)
  noeffect(result)
end

"""
    ExtensibleEffects.eff_pure(handler, value)

Overwrite this for your custom effect handler, return either `ExtensibleEffects.Eff` type, or a plain value.
Plain values will be wrapped with `noeffect` automatically.
"""
function eff_pure end


# eff_applies
# -----------

"""
    ExtensibleEffects.eff_applies(handler::YourHandlerType, value::ToBeHandledEffectType) = true

Overwrite this function like above to indicate that a concrete effect is handled by a handler.
In most cases you will have `YourHandlerType = Type{ToBeHandledEffectType}`, like for `Vector` or similar.

Sometimes you need extra information without which you cannot run a specific effect. Then you need to link
the specific handler containing the required information. E.g. `Callable` needs `args` and `kwargs` to be run,
which are captured in the handler type `CallableHandler(args, kwargs)`.
Hence above you would choose YourHandlerType = `CallableHandler`, and ToBeHandledEffectType = `Callable`.
"""
eff_applies(handler, value) = false
