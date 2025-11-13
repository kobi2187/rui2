## Example UI Definitions
##
## Shows various widget tree examples for testing hit-testing

import ../core/[types, widget_builder]
import raylib

# ============================================================================
# Example 1: Simple Button Panel
# ============================================================================

proc createSimpleButtonPanel*(): WidgetTree =
  ## Three buttons in a vertical panel
  let panel = newPanel("main_panel")
    .withBounds(50, 50, 300, 200)
    .withBackgroundColor(Color(r: 40, g: 44, b: 52, a: 255))
    .withPadding(20)

  let btn1 = newButton("Click Me!", "btn_click")
    .withSize(260, 50)
    .withBackgroundColor(Color(r: 52, g: 152, b: 219, a: 255))
    .withTextColor(WHITE)

  let btn2 = newButton("Hover Me!", "btn_hover")
    .withSize(260, 50)
    .withBackgroundColor(Color(r: 46, g: 204, b: 113, a: 255))
    .withTextColor(WHITE)

  let btn3 = newButton("Disabled", "btn_disabled")
    .withSize(260, 50)
    .withBackgroundColor(Color(r: 127, g: 140, b: 141, a: 255))
    .withTextColor(Color(r: 200, g: 200, b: 200, a: 255))

  btn3.enabled = false

  panel.addChild(btn1)
  panel.addChild(btn2)
  panel.addChild(btn3)

  layoutVertical(panel, spacing = 15)

  return buildTree(panel)

# ============================================================================
# Example 2: Login Form
# ============================================================================

proc createLoginForm*(): WidgetTree =
  ## Login form with username/password and buttons
  let form = newPanel("login_form")
    .withBounds(100, 100, 400, 300)
    .withBackgroundColor(Color(r: 236, g: 240, b: 241, a: 255))
    .withPadding(30)

  # Title
  let title = newLabel("Login", "title")
    .withSize(340, 40)
    .withTextColor(Color(r: 44, g: 62, b: 80, a: 255))

  # Username field
  let lblUsername = newLabel("Username:", "lbl_username")
    .withSize(340, 24)
    .withTextColor(Color(r: 52, g: 73, b: 94, a: 255))

  let inputUsername = newTextInput("Enter username", "input_username")
    .withSize(340, 40)
    .withBackgroundColor(WHITE)

  # Password field
  let lblPassword = newLabel("Password:", "lbl_password")
    .withSize(340, 24)
    .withTextColor(Color(r: 52, g: 73, b: 94, a: 255))

  let inputPassword = newTextInput("Enter password", "input_password")
    .withSize(340, 40)
    .withBackgroundColor(WHITE)

  # Buttons container
  let buttonRow = newContainer("button_row")
    .withSize(340, 50)

  let btnCancel = newButton("Cancel", "btn_cancel")
    .withSize(160, 50)
    .withBackgroundColor(Color(r: 149, g: 165, b: 166, a: 255))
    .withTextColor(WHITE)

  let btnLogin = newButton("Login", "btn_login")
    .withSize(160, 50)
    .withBackgroundColor(Color(r: 52, g: 152, b: 219, a: 255))
    .withTextColor(WHITE)

  buttonRow.addChild(btnCancel)
  buttonRow.addChild(btnLogin)
  layoutHorizontal(buttonRow, spacing = 20)

  form.addChild(title)
  form.addChild(lblUsername)
  form.addChild(inputUsername)
  form.addChild(lblPassword)
  form.addChild(inputPassword)
  form.addChild(buttonRow)

  layoutVertical(form, spacing = 10)

  return buildTree(form)

# ============================================================================
# Example 3: Dashboard with Panels
# ============================================================================

proc createDashboard*(): WidgetTree =
  ## Multi-panel dashboard layout
  let root = newContainer("dashboard")
    .withBounds(0, 0, 1200, 800)
    .withBackgroundColor(Color(r: 236, g: 240, b: 241, a: 255))

  # Header
  let header = newPanel("header")
    .withBounds(0, 0, 1200, 80)
    .withBackgroundColor(Color(r: 44, g: 62, b: 80, a: 255))
    .withPadding(20)

  let titleLabel = newLabel("Dashboard", "header_title")
    .withSize(200, 40)
    .withTextColor(WHITE)

  let btnProfile = newButton("Profile", "btn_profile")
    .withBounds(1000, 20, 100, 40)
    .withBackgroundColor(Color(r: 52, g: 152, b: 219, a: 255))
    .withTextColor(WHITE)

  header.addChild(titleLabel)
  header.addChild(btnProfile)

  # Sidebar
  let sidebar = newPanel("sidebar")
    .withBounds(0, 80, 250, 720)
    .withBackgroundColor(Color(r: 52, g: 73, b: 94, a: 255))
    .withPadding(15)

  let navItems = @[
    ("Home", "nav_home"),
    ("Analytics", "nav_analytics"),
    ("Reports", "nav_reports"),
    ("Settings", "nav_settings")
  ]

  for (text, id) in navItems:
    let btn = newButton(text, id)
      .withSize(220, 40)
      .withBackgroundColor(Color(r: 71, g: 95, b: 119, a: 255))
      .withTextColor(WHITE)
    sidebar.addChild(btn)

  layoutVertical(sidebar, spacing = 10)

  # Main content area
  let contentArea = newPanel("content")
    .withBounds(250, 80, 950, 720)
    .withBackgroundColor(WHITE)
    .withPadding(30)

  # Stats cards
  let statsRow = newContainer("stats_row")
    .withBounds(280, 110, 920, 150)

  let stats = @[
    ("Users", "1,234", "card_users"),
    ("Revenue", "$45.6K", "card_revenue"),
    ("Orders", "892", "card_orders")
  ]

  var cardX = 280.0'f32
  for (title, value, id) in stats:
    let card = newPanel(id)
      .withBounds(cardX, 110, 280, 120)
      .withBackgroundColor(Color(r: 52, g: 152, b: 219, a: 255))
      .withPadding(20)
      .withZIndex(5)

    let cardTitle = newLabel(title, id & "_title")
      .withSize(240, 24)
      .withTextColor(WHITE)

    let cardValue = newLabel(value, id & "_value")
      .withSize(240, 40)
      .withTextColor(WHITE)

    card.addChild(cardTitle)
    card.addChild(cardValue)
    layoutVertical(card, spacing = 10)

    statsRow.addChild(card)
    cardX += 300

  contentArea.addChild(statsRow)

  root.addChild(header)
  root.addChild(sidebar)
  root.addChild(contentArea)

  return buildTree(root)

# ============================================================================
# Example 4: Overlapping Widgets (Z-Index Test)
# ============================================================================

proc createOverlappingTest*(): WidgetTree =
  ## Overlapping widgets with different z-indices
  let root = newContainer("overlap_test")
    .withBounds(0, 0, 800, 600)
    .withBackgroundColor(Color(r: 230, g: 230, b: 230, a: 255))

  # Create overlapping panels
  let panel1 = newPanel("panel_back")
    .withBounds(100, 100, 300, 200)
    .withBackgroundColor(Color(r: 231, g: 76, b: 60, a: 200))
    .withZIndex(1)

  let panel2 = newPanel("panel_middle")
    .withBounds(200, 150, 300, 200)
    .withBackgroundColor(Color(r: 52, g: 152, b: 219, a: 200))
    .withZIndex(2)

  let panel3 = newPanel("panel_front")
    .withBounds(300, 200, 300, 200)
    .withBackgroundColor(Color(r: 46, g: 204, b: 113, a: 200))
    .withZIndex(3)

  # Add labels to identify panels
  let label1 = newLabel("Z=1 (Back)", "label1")
    .withPosition(20, 20)
    .withTextColor(WHITE)

  let label2 = newLabel("Z=2 (Middle)", "label2")
    .withPosition(20, 20)
    .withTextColor(WHITE)

  let label3 = newLabel("Z=3 (Front)", "label3")
    .withPosition(20, 20)
    .withTextColor(WHITE)

  panel1.addChild(label1)
  panel2.addChild(label2)
  panel3.addChild(label3)

  root.addChild(panel1)
  root.addChild(panel2)
  root.addChild(panel3)

  return buildTree(root)
