var DOMNodeMock, DOMParserMock, decodeXML;

DOMNodeMock = function(nodeName, nodeValue) {
  this.nodeName = nodeName;
  this.nodeValue = nodeValue;
  Object.defineProperty(this, 'parentNode', {
    value: null,
    writable: true
  });
};

DOMNodeMock.prototype = {
  get_firstChild: function() {
    return this.childNodes[0];
  },
  get_nextSibling: function() {
    var index;
    index = this.parentNode.childNodes.indexOf(this);
    return this.parentNode.childNodes[index + 1];
  },
  get_textContent: function() {
    if (!this.childNodes) {
      return this.nodeValue || '';
    }
    return this.childNodes.map(function(child) {
      return child.textContent;
    }).join('');
  },
  hasChildNodes: function() {
    return this.childNodes && this.childNodes.length > 0;
  }
};

decodeXML = function(text) {
  if (text.indexOf('&') < 0) {
    return text;
  }
  return text.replace(/&(#(x[0-9a-f]+|\d+)|\w+);/gi, function(all, entityName, number) {
    if (number) {
      return String.fromCharCode((number[0] === 'x' ? parseInt(number.substring(1), 16) : +number));
    }
    switch (entityName) {
      case 'amp':
        return '&';
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'quot':
        return '"';
      case 'apos':
        return '\'';
    }
    return '&' + entityName + ';';
  });
};

DOMParserMock = function() {};

DOMParserMock.prototype.parseFromString = function(content) {
  var lastLength, nodes;
  content = content.replace(/<\?[\s\S]*?\?>|<!--[\s\S]*?-->/g, '').trim();
  nodes = [];
  content = content.replace(/>([\s\S]+?)</g, function(all, text) {
    var i, node;
    i = nodes.length;
    node = new DOMNodeMock('#text', decodeXML(text));
    nodes.push(node);
    if (node.textContent.trim().length === 0) {
      return '><';
    }
    return '>' + i + ',<';
  });
  content = content.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, function(all, text) {
    var i, node;
    i = nodes.length;
    node = new DOMNodeMock('#text', text);
    nodes.push(node);
    return i + ',';
  });
  lastLength = void 0;
  while (true) {
    lastLength = nodes.length;
    content = content.replace(/<([\w\:]+)((?:[\s\w:=]|'[^']*'|"[^"]*")*)(?:\/>|>([\d,]*)<\/[^>]+>)/g, function(all, name, attrs, content) {
      var children, i, node;
      i = nodes.length;
      node = new DOMNodeMock(name);
      children = [];
      if (content) {
        content = content.split(',');
        content.pop();
        content.forEach(function(child) {
          var childNode;
          childNode = nodes[+child];
          childNode.parentNode = node;
          children.push(childNode);
        });
      }
      node.childNodes = children;
      nodes.push(node);
      return i + ',';
    });
    if (!(lastLength < nodes.length)) {
      break;
    }
  }
  return {
    documentElement: nodes.pop()
  };
};

exports.DOMParserMock = DOMParserMock;
