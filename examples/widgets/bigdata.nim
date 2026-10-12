## Big data without loading it: a million-line text file, a 200,000-row CSV and
## a 100,000-row SQLite table, each shown through a row source. Only the rows on
## screen are ever read, in the background; rows that have not arrived yet show
## as grey placeholders. Scroll fast and watch them fill in.
##
##   nim c -r -d:useGraphics examples/widgets/bigdata.nim [theme]
##
## The files are made in the temp directory the first time.

import rui
import std/[os, strformat]
import db_connector/db_sqlite

let dir = getTempDir() / "rui_bigdata"
createDir dir
let linesPath = dir / "lines.txt"
let csvPath = dir / "people.csv"
let dbPath = dir / "people.db"

proc make() =
  if not fileExists(linesPath):
    let f = open(linesPath, fmWrite)
    for i in 0 ..< 1_000_000: f.writeLine &"line {i}: the quick brown fox jumps over the lazy dog"
    f.close()
  if not fileExists(csvPath):
    let f = open(csvPath, fmWrite)
    f.writeLine "id,name,city,score"
    for i in 0 ..< 200_000:
      f.writeLine &"{i},\"Person, {i}\",{(if i mod 3 == 0: \"Rome\" else: \"Oslo\")},{(i * 37) mod 1000}"
    f.close()
  if not fileExists(dbPath):
    let db = db_sqlite.open(dbPath, "", "", "")
    db.exec(sql"CREATE TABLE people (id INTEGER, name TEXT, city TEXT, score INTEGER)")
    db.exec(sql"BEGIN")
    for i in 0 ..< 100_000:
      db.exec(sql"INSERT INTO people VALUES (?, ?, ?, ?)", i, "Person " & $i,
              (if i mod 3 == 0: "Rome" else: "Oslo"), (i * 37) mod 1000)
    db.exec(sql"COMMIT")
    db.close()
make()

let app = newApp("RUI2 - big data", 1000, 520)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "daylight")

let lines = newLinesSource(linesPath)
let csv = newDelimitedSource(csvPath)
let sqlite = newSqliteSource(dbPath, "people")

let root = ui:
  Padding(padding = EdgeInsets.all(16.0)):
    Column(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.start):
      Label(text = "Big data without loading it", fontSize = 22.0, bold = true)
      Row(spacing = 12.0):
        Column(spacing = 4.0, crossAxisAlignment = CrossAxisAlignment.start):
          Label(text = "1,000,000 lines", bold = true)
          ListView(items = -> lines, visibleRows = 16).size(270, 380)
        Column(spacing = 4.0, crossAxisAlignment = CrossAxisAlignment.start):
          Label(text = "CSV, 200,000 rows (not sortable)", bold = true)
          DataTable(rows = -> csv, showFilter = false, visibleRows = 15).size(300, 380)
        Column(spacing = 4.0, crossAxisAlignment = CrossAxisAlignment.start):
          Label(text = "SQLite, 100,000 rows: sort and filter in SQL", bold = true)
          DataTable(rows = -> sqlite, visibleRows = 14).size(360, 380)

app.setRootWidget(root)
app.run()
lines.close()
csv.close()
sqlite.close()
