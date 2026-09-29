# ``MVIKit``

Model-View-Intent for SwiftUI: a pure reducer, effects as data, and an observable store.

## Overview

In MVI, the view never changes state. It sends an intent that describes what happened. A pure ``Reducer`` applies the intent to the state and returns an ``Effect`` that describes any async work. When that work finishes, its result comes back through ``Send`` as another intent. The ``Store`` runs this loop and is the only object a view talks to.

```text
View ──send(intent)──▶ Store ──reduce──▶ State ──▶ View
                         │                  ▲
                         └──Effect──async───┘ (as new intents)
```

Because the reducer is the only place state changes, every transition has a named cause and can be tested without UI. Give an effect an ``EffectID`` and starting it again cancels the run in flight, so a stale response can't overwrite a fresh one.

For a complete app built on MVIKit, see [Cinematic](https://github.com/Khizanag/Cinematic-iOS).

## Topics

### The loop

- ``Reducer``
- ``Store``

### Side effects

- ``Effect``
- ``EffectID``
- ``Send``

### Modeling async state

- ``LoadingPhase``
