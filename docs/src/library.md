# ExtensibleEffects Public API

```@meta
CurrentModule = ExtensibleEffects
```

## Usage and Syntax

Autorun
```@docs
@syntax_eff
@syntax_eff_noautorun
noautorun
```

Explicit introduction of effects
```@docs
effect
noeffect
```

Explicit use of handlers
```@docs
runhandlers
@runhandlers
```

## Interface

Core Interface
```@docs
eff_applies
eff_pure
eff_flatmap
```

optional extra for autorun (in 99% not needed)
```@docs
eff_autohandler
```

for developing advanced effects like `State`
```@docs
runhandler
runhandler_not_applies
```

for developing composable effect-handler-macros
```@docs
@insert_into_runhandlers
```

## Effect Handlers

Writer
```@docs
WriterHandler
```

Callable
```@docs
CallableHandler
@runcallable
```

State
```@docs
StateHandler
@runstate
```

ContextManager
```@docs
ContextManagerHandler
@runcontextmanager
@runcontextmanager_
ContextManagerCombinedHandler
```

## Internals

Core DataTypes
```@docs
Eff
Continuation
NoEffect
```

autorun
```@docs
autorun
NoAutoRun
```

runlast
```@docs
runlast
runlast_ifpossible
```