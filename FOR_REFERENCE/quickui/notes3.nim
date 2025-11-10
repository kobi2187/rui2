# notes3.nim with regard to app's state management

# Current (using any):
type State = object
  data: Table[string, any]

# Better approach:
type
  StateKey[T] = object
    id: string

proc newKey[T](name: string): StateKey[T] =
  StateKey[T](id: name)

type State = ref object
  data: TableRef[string, RootRef]  # RootRef is still not ideal but better than any

proc set*[T](state: State, key: StateKey[T], value: T) =
  state.data[key.id] = cast[RootRef](value)

proc get*[T](state: State, key: StateKey[T]): T =
  cast[T](state.data[key.id])

# Usage:
let countKey = newKey[int]("count")
state.set(countKey, 0)
let count = state.get(countKey)
