Let me suggest a core widget set that would be essential for both direct use and as building blocks for custom widgets:

Basic Interactive Elements:
1. Button
2. TextInput
3. Checkbox
4. RadioButton
5. ScrollBar
6. Slider

Basic Display Elements:
1. Label
2. Icon
3. Image
4. ProgressBar
5. Separator

Basic Containers (we already defined these):
1. HStack/VStack
2. Grid
3. Dock
4. Overlay
5. WrapFlow

Complex but Essential:
1. TextArea (multi-line text with selection)
2. ScrollView (container with scrollbars)
3. List (vertical items with selection)
4. ComboBox (dropdown selection)

The key is these widgets should be:
1. Well-tested
2. Performant
3. Handle all edge cases
4. Support theming
5. Properly handle focus/keyboard

This gives developers:
1. Common widgets ready to use
2. Examples of proper implementation
3. Building blocks for custom widgets
4. Core functionality handled

Everything else (TreeView, DataGrid, TabView, etc.) could be built using these basics.