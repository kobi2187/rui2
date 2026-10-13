## Store: named, typed state.

import std/unittest
import rui

suite "store":

  test "declare, read and write by name":
    let s = newStore()
    let count = s.declare("count", 1)
    s.set("count", 5)
    check count.value == 5
    check s.get[:int]("count") == 5
    check s.names == @["count"]

  test "the wrong type or an unknown name is an error":
    let s = newStore()
    discard s.declare("n", 1)
    expect StoreError: discard s.linkFor[:string]("n")
    expect StoreError: discard s.linkFor[:int]("missing")
    expect StoreError: discard s.declare("n", 2)

  test "text view of scalars":
    let s = newStore()
    let n = s.declare("n", 1)
    let f = s.declare("f", 1.5)
    let b = s.declare("b", false)
    let t = s.declare("t", "x")
    check s.setText("n", "42") and n.value == 42
    check s.setText("f", "2.25") and f.value == 2.25
    check s.setText("b", "yes") and b.value
    check s.setText("t", "hello") and t.value == "hello"
    check not s.setText("n", "abc")
    check n.value == 42
    check s.getText("b") == "true"

  test "format fills {name} and honours doubled braces":
    let s = newStore()
    discard s.declare("name", "Ada")
    discard s.declare("n", 3)
    check s.format("Hi {name}, {n} {{ok}}") == "Hi Ada, 3 {ok}"
    expect StoreError: discard s.format("{nope}")

  test "interpolated follows its entries":
    let s = newStore()
    let name = s.declare("name", "Ada")
    let greeting = s.interpolated("Hello, {name}!")
    check greeting.value == "Hello, Ada!"
    name.value = "Bob"
    check greeting.value == "Hello, Bob!"

suite "state: block":
  test "declares the Store and a typed Link per entry":
    state:
      count: int = 0
      name: string = ""
      volume = 0.5
      ratio: float32 = 2
    count.value = 3
    check store.get[:int]("count") == 3                  # the Link and the name are one value
    check name.value == ""
    check volume.value == 0.5
    check ratio.value == 2.0'f32
    check store.names == @["count", "name", "volume", "ratio"]
  test "state(name): names the Store":
    state(app):
      n = 1
    check app.get[:int]("n") == 1 and n.value == 1
