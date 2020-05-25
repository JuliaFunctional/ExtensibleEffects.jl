"""
it turns out that the evaluation of NoEffect alters the execution order, as flatmap(continuation, ::Eff) runs
continuation until a next Eff is found, including NoEffect.

E.g. within ``Eff(c::ContextManager, continuation)``, the evaluation  ``c(continuation)`` calls `continuation(value)`
internally, which will return the next NoEffect if it is still there, or run everything, if the NoEffect is already
evaluated. In order to preserver the correct entering/exiting of effect evaluations like ContextManager, we
should not evaluate NoEffects until necessary.
"""
function _run_only_initial_noeffect(eff::Eff)
  interpreted_continuation = if isempty(eff.cont)
    Continuation(x -> _eff_pure(NoEffect, x))
  else
    Continuation(x -> _run_only_initial_noeffect(eff.cont(x)))
  end

  if eff_applies(NoEffect, eff.value)
    _eff_flatmap(NoEffect, interpreted_continuation, eff.value)
  else
    eff  # just don't do anything
  end
end
