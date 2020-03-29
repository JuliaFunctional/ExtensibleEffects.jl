
"""
extract final value from Eff with all effects (but NoEffect) already run
"""
function runlast(eff::Eff)
  # at last all Effects have stacked up a last NoEffect, which we can simply run
  final = runeffect(NoEffect, eff)
  @assert isempty(final.cont) "expected eff without continuation, but found cont=$(eff.cont)"
  @assert final.value isa NoEffect "not all effects have been handled, found $(eff.value)"
  final.value.value
end

"""
convenience wrapper to better use runeffect in |>
"""
runeffect(handler) = eff -> runeffect(handler, eff)

"""
key method to run an effect on some effecthandler Eff

note that we represent effectrunners as plain types in order to associate
standard effect runners with types like Vector, Option, ...
"""
function runeffect(handler, eff::Eff)
  if isempty(eff.cont)
    interpreted_continuation = Continuation(x -> _eff_pure(handler, x))
    _eff_flatmap(handler, interpreted_continuation, eff.value)
  else
    interpreted_continuation = Continuation(x -> runeffect(handler, eff.cont(x)))
    _eff_flatmap(handler, interpreted_continuation, eff.value)
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

"""
  _eff_flatmap(...)

checks whether the current value matches the current effect.
If so, it calls `eff_flatmap`, if not, it knows what to do.
"""
function _eff_flatmap(handler, interpreted_continuation::Continuation, value)
  if eff_applies(handler, value)
    result = eff_flatmap(handler, interpreted_continuation, value)
    # provide convenience wrapper if someone forgets to return an Eff
    isa(result, Eff) ? result : noeffect(result)
  else
    Eff(value, interpreted_continuation)
  end
end

"""
    eff_flatmap(continuation, value::EffType)::Union{EffType, Eff}

Overwrite this for your custom effect handler, return either EffType or an Eff.
"""
function eff_flatmap end

"""
for combining multiple effects it is very handy to dispatch on EffType for Union{EffType1, EffType2}

however for standard effects we can ommit EffType, as we now it by typeof(value)
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
