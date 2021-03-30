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
@runhandlers,
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