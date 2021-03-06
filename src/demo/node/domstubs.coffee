### Any copyright is dedicated to the Public Domain.
# http://creativecommons.org/publicdomain/zero/1.0/
###

sheet =
  cssRules: []
  insertRule: (rule) ->
    @cssRules.push rule
    return

style = sheet: sheet

xmlEncode = (s) ->
  i = 0
  ch = undefined
  s = String s
  while i < s.length and
  (ch = s[i]) != '&' and
  ch != '<' and
  ch != '"' and
  ch != '\n' and
  ch != '\ud' and
  ch != '\u9'
    i++
  return s if i >= s.length
  buf = s.substring 0, i
  while i < s.length
    ch = s[i++]
    switch ch
      when '&' then buf += '&amp;'
      when '<' then buf += '&lt;'
      when '"' then buf += '&quot;'
      when '\n' then buf += '&#xA;'
      when '\ud' then buf += '&#xD;'
      when '\u9' then buf += '&#x9;'
      else buf += ch
  buf

global.btoa = (chars) ->
  digits = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='
  buffer = ''
  i = undefined
  n = undefined
  i = 0
  n = chars.length
  while i < n
    b1 = chars.charCodeAt(i) & 0xFF
    b2 = chars.charCodeAt(i + 1) & 0xFF
    b3 = chars.charCodeAt(i + 2) & 0xFF
    d1 = b1 >> 2
    d2 = (b1 & 3) << 4 | b2 >> 4
    d3 = if i + 1 < n then (b2 & 0xF) << 2 | b3 >> 6 else 64
    d4 = if i + 2 < n then b3 & 0x3F else 64
    buffer += digits.charAt(d1) + digits.charAt(d2) + digits.charAt(d3) + digits.charAt(d4)
    i += 3
  buffer

DOMElement = (name) ->
  @nodeName = name
  @childNodes = []
  @attributes = {}
  @textContent = ''
  return

DOMElement.prototype =

  setAttributeNS: (NS, name, value) ->
    value = value or ''
    value = xmlEncode value
    @attributes[name] = value
    return

  appendChild: (element) ->
    childNodes = @childNodes
    if childNodes.indexOf(element) is -1
      childNodes.push element
    return

  # DOMElement_toString
  toString: ->
    attrList = []
    for e in @attributes
      attrList.push "#{e} = #{xmlEncode @attributes[i]}"
    if @nodeName is 'svg:tspan' or @nodeName is 'svg:style'
      encText = xmlEncode @textContent
      return """
      <#{@nodeName} #{attrList.join ' '}>
        #{encText}
      </#{@nodeName}>
      """
    else if @nodeName is 'svg:svg'
      ns = [
        'xmlns:xlink="http://www.w3.org/1999/xlink"'
        'xmlns:svg="http://www.w3.org/2000/svg"'
      ].join ' '
      """
      <#{@nodeName} #{ns} #{attrList.join ' '}>
        #{@childNodes.join ''}
      </#{@nodeName}>
      """
    else
      """
      <#{@nodeName} #{attrList.join ' '}>
        #{@childNodes.join ''}
      </#{@nodeName}>
      """

  # DOMElement_cloneNode
  cloneNode: ->
    newNode = new DOMElement @nodeName
    newNode.childNodes = @childNodes
    newNode.attributes = @attributes
    newNode.textContent = @textContent
    newNode

global.document =
  childNodes: []

  getElementById: (id) ->
    return style if id is 'PDFJS_FONT_STYLE_TAG'
    return

  createElementNS: (NS, element) ->
    elObject = new DOMElement element
    elObject

# ---
# generated by js2coffee 2.0.0