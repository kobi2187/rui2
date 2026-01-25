import ../rui

proc main() =
  let app = newApp(
    title = "Basic Test",
    width = 800,
    height = 600,
    fps = 60
  )

  # Here you would set up your root widget and other app configurations
  # For example:
  # app.setRootWidget(yourRootWidget)

  app.start()

when isMainModule:
  main()