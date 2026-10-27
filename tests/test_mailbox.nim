## Messages from other threads (mailbox.nim): a thread sends values, never
## touches UI state; the UI thread receives them between frames, in order, and
## changes what it likes. Links and LinkSeqs know which thread is the UI's.

import std/[unittest, os, monotimes, times]
import rui
import ui_harness

proc waitFor(r: Rig, cond: proc(): bool, seconds = 3.0) =
  let until = getMonoTime() + initDuration(milliseconds = int(seconds * 1000))
  while not cond() and getMonoTime() < until:
    r.frame(1)
    sleep(5)

proc counter(box: Mailbox[int]) {.thread.} =
  for i in 1 .. 100: box.send(i)

proc greeter(box: Mailbox[string]) {.thread.} =
  var s = "hello"
  box.send(s)
  s.add " again"                     # the message was a copy: this is not seen
  box.send(s)

proc lateSender(box: Mailbox[int]) {.thread.} =
  sleep(100)
  box.send(1)                        # after close: dropped, and safe

proc whereAmI(box: Mailbox[bool]) {.thread.} =
  box.send(onUiThread())

suite "Mailbox":
  test "a thread's messages arrive on the UI thread, all of them, in order":
    let shown = newLink(0)
    let label = newLabel(text = "0")
    let r = newRig(stack(label))
    var got: seq[int]
    var threads: seq[int]
    let box = newMailbox(proc(n: int) =
      got.add n
      threads.add getThreadId()
      shown.value = n                  # UI state, changed on the UI thread
      label.text = $n)
    var t: Thread[Mailbox[int]]
    createThread(t, counter, box)
    joinThread(t)
    check got.len == 0                 # nothing until the UI thread takes them
    check box.pending == 100
    r.waitFor(proc(): bool = got.len == 100)
    check got == (block: (var s: seq[int]; (for i in 1 .. 100: s.add i); s))
    for id in threads: check id == getThreadId()
    check shown.value == 100 and label.text == "100"
    box.close()
    disposeTree(r.root)

  test "latest only: one message a frame, the newest":
    var got: seq[int]
    let box = newMailbox(proc(n: int) = (got.add n), latest = true)
    var t: Thread[Mailbox[int]]
    createThread(t, counter, box)
    joinThread(t)
    discard runPollers()
    check got == @[100]
    box.close()

  test "a message is a copy; strings cross intact":
    var got: seq[string]
    let box = newMailbox(proc(s: string) = got.add s)
    var t: Thread[Mailbox[string]]
    createThread(t, greeter, box)
    joinThread(t)
    discard runPollers()
    check got == @["hello", "hello again"]
    box.close()

  test "after close nothing is delivered, and a late sender is harmless":
    var got = 0
    let polls = pollerCount()
    let box = newMailbox(proc(n: int) = inc got)
    check pollerCount() == polls + 1 and box.isOpen
    var t: Thread[Mailbox[int]]
    createThread(t, lateSender, box)
    box.close()
    check pollerCount() == polls and not box.isOpen
    joinThread(t)
    discard runPollers()
    check got == 0

  test "the UI thread is known: a thread is told it is not it":
    check onUiThread()
    var answer: seq[bool]
    let box = newMailbox(proc(b: bool) = answer.add b)
    var t: Thread[Mailbox[bool]]
    createThread(t, whereAmI, box)
    joinThread(t)
    discard runPollers()
    check answer == @[false]
    box.close()
