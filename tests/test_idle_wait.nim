import std/[unittest, monotimes, times, options]
import idle_wait

suite "idle blocking":
  let now = getMonoTime()
  let ms = proc(n: int): Duration = initDuration(milliseconds = n)

  test "blocks until the idle refresh when no timer is pending":
    check idleWaitFor(now, none(MonoTime), now + ms(1000)) == ms(1000)

  test "wakes for a repaint timer sooner than the refresh":
    check idleWaitFor(now, some(now + ms(530)), now + ms(1000)) == ms(530)

  test "a timer later than the refresh does not extend the wait":
    check idleWaitFor(now, some(now + ms(5000)), now + ms(1000)) == ms(1000)

  test "something already due costs a millisecond, not a spin":
    check idleWaitFor(now, some(now - ms(5)), now + ms(1000)) == ms(1)
    check idleWaitFor(now, none(MonoTime), now - ms(5)) == ms(1)

  test "a cap shortens the wait (scripting polls once a frame)":
    check idleWaitFor(now, none(MonoTime), now + ms(1000), some(ms(16))) == ms(16)
    check idleWaitFor(now, some(now + ms(4)), now + ms(1000), some(ms(16))) == ms(4)
