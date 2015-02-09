# optimised CSS custom property getter/setter
CustomStyle = do ->
  # As noted on: http://www.zachstronaut.com/posts/2009/02/17/
  #              animate-css-transforms-firefox-webkit.html
  # in some versions of IE9 it is critical that ms appear in this list
  # before Moz
  prefixes = [
    'ms'
    'Moz'
    'Webkit'
    'O'
  ]
  _cache = {}

  CustomStyle = ->

  CustomStyle.getProp = (propName, element) ->
    # check cache only when no element is given
    return _cache[propName] if arguments.length is 1 and
      typeof _cache[propName] is 'string'

    element = element or document.documentElement
    style = element.style

    prefixed = undefined
    uPropName = undefined

    # test standard property first
    if typeof style[propName] is 'string'
      return _cache[propName] = propName

    # capitalize
    uPropName = propName.charAt(0).toUpperCase() + propName.slice(1)

    # test vendor specific properties
    for prefix in prefixes
      prefixed = prefix + uPropName
      return _cache[propName] = prefixed if typeof style[prefixed] is 'string'

    #if all fails then set to undefined
    _cache[propName] = 'undefined'

  CustomStyle.setProp = (propName, element, str) ->
    prop = @getProp propName
    if prop isnt 'undefined'
      element.style[prop] = str
    return

  CustomStyle