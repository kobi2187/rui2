## An app that has drawn with the shaders (a Button's box, its shadow) closes
## without crashing. A GPU object held in a plain global was destroyed after
## closeWindow had torn the GL context down -- SIGSEGV on every exit -- and
## no check ever closed a window the way an app does.

import rui

let app = newApp("clean exit", 300, 200)
let root = newVStack()
root.addChild(newButton(text = "Draws through the SDF shaders"))
root.addChild(newCheckbox(text = "and a smooth tick", initialChecked = true))
app.setRootWidget(root)
app.run(maxFrames = 5)
echo "exited cleanly"
