## Avatar and AvatarStack (basic/avatar.nim): initials, a colour of the name's
## own that a letter reads on, stack geometry with "+N".

import std/[unittest]
import rui

suite "avatars":
  test "initials: first and last word, capitals, unicode; ? for none":
    check initialsOf("Ada Lovelace") == "AL"
    check initialsOf("grace") == "G"
    check initialsOf("  édith   piaf ") == "ÉP"
    check initialsOf("Jean Paul Sartre") == "JS"
    check initialsOf("") == "?"

  test "the same name has the same colour; names differ; black or white reads on each":
    check colorFor("Ada") == colorFor("ada")
    var seen: seq[Color]
    for n in ["Ada", "Grace", "Alan", "Edsger", "Barbara", "Ken"]:
      let c = colorFor(n)
      check max(contrastRatio(c, BLACK), contrastRatio(c, WHITE)) >= 4.5
      if c notin seen: seen.add c
    check seen.len >= 4

  test "a stack shows maxShown and a +N slot, each overlapping the last":
    let s = stackSlots(6, 3, 32, 0.25)
    check s.len == 4                      # three avatars and "+3"
    check s[1] - s[0] == 24
    check stackSlots(2, 3, 32, 0.25).len == 2
    let w = newAvatarStack(names = @["a", "b", "c", "d", "e"], maxShown = 3, size = 32, overlap = 0.25)
    w.layout()
    check w.bounds.width == float32(3 * 24 + 32 + 4)
