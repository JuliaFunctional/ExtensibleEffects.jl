# TODO try to construct an autorunner

struct AutoRun{T}
  found_effects::T
end
AutoRun() = AutoRun(())


ExtensibleEffects.eff_applies(::AutoRun, v) = true
ExtensibleEffects.eff_flatmap(::AutoRun, cont, value)
function autorun(eff::Eff)
  @match(eff.value) do f
    f(noeffect::NoEffect) =
end
