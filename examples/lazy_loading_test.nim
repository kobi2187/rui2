## Lazy Loading Test - RUI2 Example
##
## Demonstrates virtual rendering and lazy loading:
## 1. Simulates 1,000,000 items (like a large database)
## 2. Only loads 100 items at a time (pagination)
## 3. Loads more as you scroll near the bottom
## 4. Shows "Loading..." for unloaded items
##
## This approach allows handling HUGE datasets without memory issues!

import ../rui
import std/[strformat, times]

# ============================================================================
# Simulated Database
# ============================================================================

type
  SimulatedDB = object
    totalItems: int

proc newDB(totalItems: int): SimulatedDB =
  ## Create a simulated database with N items
  result.totalItems = totalItems
  echo &"[DB] Initialized with {totalItems} items"

proc fetchPage(db: SimulatedDB, startIndex: int, count: int): seq[string] =
  ## Simulate fetching a page of data (like SQL LIMIT/OFFSET)
  ## In real app, this would query the database
  echo &"[DB] Fetching items {startIndex}..{startIndex + count - 1}"

  # Simulate network/database delay
  sleep(100)  # 100ms delay

  result = @[]
  for i in startIndex..<min(startIndex + count, db.totalItems):
    result.add(&"Item #{i} - Database Record")

  echo &"[DB] Fetched {result.len} items"

# ============================================================================
# Application State
# ============================================================================

type AppStore = object
  ## Application state
  listItems: Link[seq[string]]
  totalCount: Link[int]
  loadedCount: Link[int]
  statusMessage: Link[string]

var db = newDB(1_000_000)  # 1 million items!

var store = AppStore(
  listItems: newLink(@[string]()),
  totalCount: newLink(1_000_000),
  loadedCount: newLink(0),
  statusMessage: newLink("Ready to load data...")
)

# ============================================================================
# Data Loading Functions
# ============================================================================

proc loadInitialData() =
  ## Load first page of data
  echo "\n[APP] Loading initial data..."
  store.statusMessage.set("Loading initial data...")

  let firstPage = db.fetchPage(0, 100)
  store.listItems.set(firstPage)
  store.loadedCount.set(firstPage.len)
  store.statusMessage.set(&"Loaded {firstPage.len} of 1,000,000 items")

  echo &"[APP] Initial load complete: {firstPage.len} items"

proc loadMore(startIndex: int, count: int) =
  ## Load more data (pagination)
  echo &"\n[APP] Load more requested: startIndex={startIndex}, count={count}"

  # Don't load if we already have this data
  let currentLoaded = store.listItems.get().len
  if startIndex <= currentLoaded:
    echo "[APP] Data already loaded, skipping"
    return

  store.statusMessage.set(&"Loading more data...")

  let nextPage = db.fetchPage(startIndex, count)

  # Append to existing items
  var currentItems = store.listItems.get()
  currentItems.add(nextPage)
  store.listItems.set(currentItems)
  store.loadedCount.set(currentItems.len)

  store.statusMessage.set(&"Loaded {currentItems.len} of 1,000,000 items")
  echo &"[APP] Now have {currentItems.len} items loaded"

proc onScrollNearEnd() =
  ## Called when user scrolls near the bottom
  echo "[APP] User scrolled near end, will load more on next render"
  # The onLoadMore callback will handle actual loading

# ============================================================================
# Build Widget Tree
# ============================================================================

proc buildUI(): Widget =
  ## Build the UI with lazy-loading ListView
  result = VStack(spacing = 10, padding = 10):
    # Title
    Label(text = "Lazy Loading Demo - 1 Million Items!")

    # Status
    Label(text = store.statusMessage.get())

    # Load button
    Button(
      text = "Load Initial Data (100 items)",
      onClick = loadInitialData
    )

    # Stats
    Label(text = &"Loaded: {store.loadedCount.get()} / {store.totalCount.get()} items")

    # ListView with lazy loading
    ListView(
      items = store.listItems.get(),
      totalItemCount = store.totalCount.get(),  # Tell it total is 1M
      itemHeight = 24.0,
      onLoadMore = loadMore,                     # Callback to load more
      onScrollNearEnd = onScrollNearEnd          # Triggered when scrolling near end
    )

    # Instructions
    Label(text = "Scroll down to load more data automatically!")

# ============================================================================
# Main - Create App and Run
# ============================================================================

when isMainModule:
  echo "=" .repeat(60)
  echo "LAZY LOADING TEST - RUI2"
  echo "=" .repeat(60)
  echo ""
  echo "This demo simulates a database with 1,000,000 items."
  echo "Only 100 items are loaded at a time (pagination)."
  echo "More items load automatically as you scroll down."
  echo ""
  echo "Memory usage stays LOW because we don't load everything!"
  echo ""

  # Create the app
  let app = newApp(
    title = "Lazy Loading Test - 1M Items",
    width = 600,
    height = 500,
    fps = 60
  )

  # Build and set the widget tree
  let ui = buildUI()
  app.setRootWidget(ui)

  echo "App ready. Click 'Load Initial Data' to begin."
  echo ""

  # Start the main loop
  app.start()

  echo "App closed."
