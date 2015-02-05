
/* Any copyright is dedicated to the Public Domain.
 * http://creativecommons.org/publicdomain/zero/1.0/
 */
var DOMElement, sheet, style, xmlEncode;

sheet = {
  cssRules: [],
  insertRule: function(rule) {
    this.cssRules.push(rule);
  }
};

style = {
  sheet: sheet
};

xmlEncode = function(s) {
  var buf, ch, i;
  i = 0;
  ch = void 0;
  s = String(s);
  while (i < s.length && (ch = s[i]) !== '&' && ch !== '<' && ch !== '"' && ch !== '\n' && ch !== '\ud' && ch !== '\u9') {
    i++;
  }
  if (i >= s.length) {
    return s;
  }
  buf = s.substring(0, i);
  while (i < s.length) {
    ch = s[i++];
    switch (ch) {
      case '&':
        buf += '&amp;';
        break;
      case '<':
        buf += '&lt;';
        break;
      case '"':
        buf += '&quot;';
        break;
      case '\n':
        buf += '&#xA;';
        break;
      case '\ud':
        buf += '&#xD;';
        break;
      case '\u9':
        buf += '&#x9;';
        break;
      default:
        buf += ch;
    }
  }
  return buf;
};

global.btoa = function(chars) {
  var b1, b2, b3, buffer, d1, d2, d3, d4, digits, i, n;
  digits = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  buffer = '';
  i = void 0;
  n = void 0;
  i = 0;
  n = chars.length;
  while (i < n) {
    b1 = chars.charCodeAt(i) & 0xFF;
    b2 = chars.charCodeAt(i + 1) & 0xFF;
    b3 = chars.charCodeAt(i + 2) & 0xFF;
    d1 = b1 >> 2;
    d2 = (b1 & 3) << 4 | b2 >> 4;
    d3 = i + 1 < n ? (b2 & 0xF) << 2 | b3 >> 6 : 64;
    d4 = i + 2 < n ? b3 & 0x3F : 64;
    buffer += digits.charAt(d1) + digits.charAt(d2) + digits.charAt(d3) + digits.charAt(d4);
    i += 3;
  }
  return buffer;
};

DOMElement = function(name) {
  this.nodeName = name;
  this.childNodes = [];
  this.attributes = {};
  this.textContent = '';
};

DOMElement.prototype = {
  setAttributeNS: function(NS, name, value) {
    value = value || '';
    value = xmlEncode(value);
    this.attributes[name] = value;
  },
  appendChild: function(element) {
    var childNodes;
    childNodes = this.childNodes;
    if (childNodes.indexOf(element) === -1) {
      childNodes.push(element);
    }
  },
  toString: function() {
    var attrList, e, encText, ns, _i, _len, _ref;
    attrList = [];
    _ref = this.attributes;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      e = _ref[_i];
      attrList.push(e + " = " + (xmlEncode(this.attributes[i])));
    }
    if (this.nodeName === 'svg:tspan' || this.nodeName === 'svg:style') {
      encText = xmlEncode(this.textContent);
      return "<" + this.nodeName + " " + (attrList.join(' ')) + ">\n  " + encText + "\n</" + this.nodeName + ">";
    } else if (this.nodeName === 'svg:svg') {
      ns = ['xmlns:xlink="http://www.w3.org/1999/xlink"', 'xmlns:svg="http://www.w3.org/2000/svg"'].join(' ');
      return "<" + this.nodeName + " " + ns + " " + (attrList.join(' ')) + ">\n  " + (this.childNodes.join('')) + "\n</" + this.nodeName + ">";
    } else {
      return "<" + this.nodeName + " " + (attrList.join(' ')) + ">\n  " + (this.childNodes.join('')) + "\n</" + this.nodeName + ">";
    }
  },
  cloneNode: function() {
    var newNode;
    newNode = new DOMElement(this.nodeName);
    newNode.childNodes = this.childNodes;
    newNode.attributes = this.attributes;
    newNode.textContent = this.textContent;
    return newNode;
  }
};

global.document = {
  childNodes: [],
  getElementById: function(id) {
    if (id === 'PDFJS_FONT_STYLE_TAG') {
      return style;
    }
  },
  createElementNS: function(NS, element) {
    var elObject;
    elObject = new DOMElement(element);
    return elObject;
  }
};
