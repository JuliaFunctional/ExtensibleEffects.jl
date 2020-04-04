"""
    runhandlers(handlers, eff)
    runhandlers((Vector, Option), eff)::Vector{Option{...}}

run all handlers such that the first handler will define the most outer container
"""
function runhandlers(all_handlers::Union{Tuple, Vector}, eff)
  # handle from right to left to have a result type which nesting mimicks the given type-order
  all_handled = Base.foldr(all_handlers, init=eff) do handler, acc
    runhandler(handler, acc)
  end
  runlast(all_handled)
end

"""
extract final value from Eff with all effects (but NoEffect) already run
"""
function runlast(eff::Eff)
  # at last all Effects have stacked up a last NoEffect, which we can simply run
  final = runhandler(NoEffect, eff)
  @assert isempty(final.cont) "expected eff without continuation, but found cont=$(final.cont)"
  @assert final.value isa NoEffect "not all effects have been handled, found $(final.value)"
  final.value.value
end


"""
convenience wrapper to better use runhandler in |>
"""
runhandler(handler) = eff -> runhandler(handler, eff)

"""
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
  # provide convenience wrapper if someone forgets to return an Eff
  result = eff_flatmap(handler, interpreted_continuation, value)
  isa(result, Eff) ? result : noeffect(result)
end

"""
    eff_flatmap(handler, interpreted_continuation, value)
    eff_flatmap(interpreted_continuation, value)

This function is only called if ``eff_applies(handler, value)==true``.
Overwrite this for your custom effect handler to handle your effect.

While for custom effects it is handy to dispatch on the handler itself, in the simple cases
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
eff_flatmap(handler, interpreted_continuation::Continuation, value) = eff_flatmap(interpreted_continuation, value)


# eff_pure
# --------

function _eff_pure(handler, value)
  result = eff_pure(handler, value)
  isa(result, Eff) ? result : noeffect(result)
end

"""
    eff_pure(handler, value)::Union{handledtype, Eff}

Overwrite this for your custom effect handler, return either EffType or an Eff.
"""
function eff_pure end


# eff_applies
# -----------

eff_applies(handler::Type{T}, value::T) where T = true
eff_applies(handler::Type{T}, value::Other) where {T, Other} = false
