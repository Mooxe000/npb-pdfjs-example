### Any copyright is dedicated to the Public Domain.
# http://creativecommons.org/publicdomain/zero/1.0/
###

#
# Basic node example that prints document metadata and text content.
# Requires single file built version of PDF.js -- please run
# `node make singlefile` before running the example.
#
fs = require 'fs'

# HACK few hacks to let PDF.js be loaded not as a module in global space.
global.window = global
global.navigator = userAgent: 'node'
global.PDFJS = {}
global.DOMParser = (
  require './domparsermock.js'
).DOMParserMock

require '../../build/singlefile/build/pdf.combined.js'

# Loading file from file system into typed array
pdfPath = process.argv[2] or '../../web/compressed.tracemonkey-pldi-09.pdf'
data = new Uint8Array fs.readFileSync pdfPath

# Will be using promises to load document, pages and misc data instead of
# callback.
PDFJS.getDocument data
.then (doc) ->
  numPages = doc.numPages
  console.log '# Document Loaded'
  console.log 'Number of Pages: ' + numPages
  console.log()

  lastPromise = undefined # will be used to chain promises
  lastPromise = doc.getMetadata()
  .then (data) ->
    console.log '# Metadata Is Loaded'
    console.log '## Info'
    console.log JSON.stringify data.info, null, 2
    console.log()
    if data.metadata
      console.log '## Metadata'
      console.log JSON.stringify data.metadata.metadata, null, 2
      console.log()
    return

  loadPage = (pageNum) ->
    doc.getPage pageNum
    .then (page) ->
      console.log "# Page #{pageNum}"
      viewport = page.getViewport 1.0
      console.log "Size: #{viewport.width}x#{viewport.height}"
      console.log()
      page.getTextContent()
      .then (content) ->
        # Content contains lots of information about the text layout and
        # styles, but we need only strings at the moment
        strings = content.items.map (item) ->
          item.str
        console.log '## Text Content'
        console.log strings.join ' '
        return
      .then ->
        console.log()
        return

  # Loading of the first page will wait on metadata and subsequent loadings
  # will wait on the previous pages.
  i = 1
  while i <= numPages
    lastPromise = lastPromise.then loadPage.bind null, i
    i++

  lastPromise

.then ->
  console.log '# End of Document'
  return
, (err) ->
  console.error "Error: #{err}"
  return

# ---
# generated by js2coffee 2.0.0