//
//  SWXMLHash.swift
//
//  Copyright (c) 2014 David Mohundro
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

let rootElementName = "SWXMLHash_Root_Element"

/// Parser options
open class SWXMLHashOptions {
  internal init() {}
  
  /// determines whether to parse the XML with lazy parsing or not
  open var shouldProcessLazily = false
  
  /// determines whether to parse XML namespaces or not (forwards to `NSXMLParser.shouldProcessNamespaces`)
  open var shouldProcessNamespaces = false
}

/// Simple XML parser
open class SWXMLHash {
  let options: SWXMLHashOptions
  
  fileprivate init(_ options: SWXMLHashOptions = SWXMLHashOptions()) {
    self.options = options
  }
  
  class open func config(_ configAction: (SWXMLHashOptions) -> ()) -> SWXMLHash {
    let opts = SWXMLHashOptions()
    configAction(opts)
    return SWXMLHash(opts)
  }
  
  open func parse(_ xml: String) -> XMLIndexer {
    return parse((xml as NSString).data(using: String.Encoding.utf8.rawValue)!)
  }
  
  open func parse(_ data: Data) -> XMLIndexer {
    let parser: SimpleXmlParser = options.shouldProcessLazily ? LazyXMLParser(options) : XMLParser(options)
    return parser.parse(data)
  }
  
  /**
   Method to parse XML passed in as a string.
   
   - parameter xml: The XML to be parsed
   - returns: An XMLIndexer instance that is used to look up elements in the XML
   */
  class open func parse(_ xml: String) -> XMLIndexer {
    return SWXMLHash().parse(xml)
  }
  
  /**
   Method to parse XML passed in as an NSData instance.
   
   - parameter xml: The XML to be parsed
   - returns: An XMLIndexer instance that is used to look up elements in the XML
   */
  class open func parse(_ data: Data) -> XMLIndexer {
    return SWXMLHash().parse(data)
  }
  
  /**
   Method to lazily parse XML passed in as a string.
   
   - parameter xml: The XML to be parsed
   - returns: An XMLIndexer instance that is used to look up elements in the XML
   */
  class open func lazy(_ xml: String) -> XMLIndexer {
    return config { conf in conf.shouldProcessLazily = true }.parse(xml)
  }
  
  /**
   Method to lazily parse XML passed in as an NSData instance.
   
   - parameter xml: The XML to be parsed
   - returns: An XMLIndexer instance that is used to look up elements in the XML
   */
  class open func lazy(_ data: Data) -> XMLIndexer {
    return config { conf in conf.shouldProcessLazily = true }.parse(data)
  }
}

struct Stack<T> {
  var items = [T]()
  mutating func push(_ item: T) {
    items.append(item)
  }
  mutating func pop() -> T {
    return items.removeLast()
  }
  mutating func removeAll() {
    items.removeAll(keepingCapacity: false)
  }
  func top() -> T {
    return items[items.count - 1]
  }
}

protocol SimpleXmlParser {
  init(_ options: SWXMLHashOptions)
  func parse(_ data: Data) -> XMLIndexer
}

/// The implementation of NSXMLParserDelegate and where the lazy parsing actually happens.
class LazyXMLParser: NSObject, SimpleXmlParser, XMLParserDelegate {
  required init(_ options: SWXMLHashOptions) {
    self.options = options
    super.init()
  }
  
  var root = XMLElement(name: rootElementName)
  var parentStack = Stack<XMLElement>()
  var elementStack = Stack<String>()
  
  var data: Data?
  var ops: [IndexOp] = []
  let options: SWXMLHashOptions
  
  func parse(_ data: Data) -> XMLIndexer {
    self.data = data
    return XMLIndexer(self)
  }
  
  func startParsing(_ ops: [IndexOp]) {
    // clear any prior runs of parse... expected that this won't be necessary, but you never know
    parentStack.removeAll()
    root = XMLElement(name: rootElementName)
    parentStack.push(root)
    
    self.ops = ops
    let parser = Foundation.XMLParser(data: data!)
    parser.shouldProcessNamespaces = options.shouldProcessNamespaces
    parser.delegate = self
    parser.parse()
  }
  
  func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
    
    elementStack.push(elementName)
    
    if !onMatch() {
      return
    }
    let currentNode = parentStack.top().addElement(elementName, withAttributes: attributeDict as NSDictionary)
    parentStack.push(currentNode)
  }
  
  func parser(_ parser: XMLParser, foundCharacters string: String) {
    if !onMatch() {
      return
    }
    
    let current = parentStack.top()
    if current.text == nil {
      current.text = ""
    }
    
    current.text! += string
  }
  
  func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
    let match = onMatch()
    
    elementStack.pop()
    
    if match {
      parentStack.pop()
    }
  }
  
  func onMatch() -> Bool {
    // we typically want to compare against the elementStack to see if it matches ops, *but*
    // if we're on the first element, we'll instead compare the other direction.
    if elementStack.items.count > ops.count {
      return elementStack.items.starts(with: ops.map { $0.key })
    }
    else {
      return ops.map { $0.key }.starts(with: elementStack.items)
    }
  }
}

/// The implementation of NSXMLParserDelegate and where the parsing actually happens.
class XMLParser: NSObject, SimpleXmlParser, XMLParserDelegate {
  required init(_ options: SWXMLHashOptions) {
    self.options = options
    super.init()
  }
  
  var root = XMLElement(name: rootElementName)
  var parentStack = Stack<XMLElement>()
  let options: SWXMLHashOptions
  
  func parse(_ data: Data) -> XMLIndexer {
    // clear any prior runs of parse... expected that this won't be necessary, but you never know
    parentStack.removeAll()
    
    parentStack.push(root)
    
    let parser = Foundation.XMLParser(data: data)
    parser.shouldProcessNamespaces = options.shouldProcessNamespaces
    parser.delegate = self
    parser.parse()
    
    return XMLIndexer(root)
  }
  
  func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
    
    let currentNode = parentStack.top().addElement(elementName, withAttributes: attributeDict as NSDictionary)
    parentStack.push(currentNode)
  }
  
  func parser(_ parser: XMLParser, foundCharacters string: String) {
    let current = parentStack.top()
    if current.text == nil {
      current.text = ""
    }
    
    current.text! += string
  }
  
  func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
    parentStack.pop()
  }
}

open class IndexOp {
  var index: Int
  let key: String
  
  init(_ key: String) {
    self.key = key
    self.index = -1
  }
  
  func toString() -> String {
    if index >= 0 {
      return key + " " + index.description
    }
    
    return key
  }
}

open class IndexOps {
  var ops: [IndexOp] = []
  
  let parser: LazyXMLParser
  
  init(parser: LazyXMLParser) {
    self.parser = parser
  }
  
  func findElements() -> XMLIndexer {
    parser.startParsing(ops)
    let indexer = XMLIndexer(parser.root)
    var childIndex = indexer
    for op in ops {
      childIndex = childIndex[op.key]
      if op.index >= 0 {
        childIndex = childIndex[op.index]
      }
    }
    ops.removeAll(keepingCapacity: false)
    return childIndex
  }
  
  func stringify() -> String {
    var s = ""
    for op in ops {
      s += "[" + op.toString() + "]"
    }
    return s
  }
}

/// Returned from SWXMLHash, allows easy element lookup into XML data.
public enum XMLIndexer: Sequence {
  case Element(XMLElement)
  case list([XMLElement])
  case stream(IndexOps)
  case xmlError(Error)
  
  public enum Error: Error {
    case attribute(attr: String)
    case attributeValue(attr: String, value: String)
    case key(key: String)
    case index(idx: Int)
    case `init`(instance: AnyObject)
    case error
  }
  
  /// The underlying XMLElement at the currently indexed level of XML.
  public var element: XMLElement? {
    switch self {
    case .Element(let elem):
      return elem
    case .stream(let ops):
      let list = ops.findElements()
      return list.element
    default:
      return nil
    }
  }
  
  /// All elements at the currently indexed level
  public var all: [XMLIndexer] {
    switch self {
    case .list(let list):
      var xmlList = [XMLIndexer]()
      for elem in list {
        xmlList.append(XMLIndexer(elem))
      }
      return xmlList
    case .Element(let elem):
      return [XMLIndexer(elem)]
    case .stream(let ops):
      let list = ops.findElements()
      return list.all
    default:
      return []
    }
  }
  
  /// All child elements from the currently indexed level
  public var children: [XMLIndexer] {
    var list = [XMLIndexer]()
    for elem in all.map({ $0.element! }) {
      for elem in elem.children {
        list.append(XMLIndexer(elem))
      }
    }
    return list
  }
  
  /**
   Allows for element lookup by matching attribute values.
   
   - parameter attr: should the name of the attribute to match on
   - parameter value: should be the value of the attribute to match on
   - returns: instance of XMLIndexer
   */
  public func withAttr(_ attr: String, _ value: String) throws -> XMLIndexer {
    switch self {
    case .stream(let opStream):
      opStream.stringify()
      let match = opStream.findElements()
      return try match.withAttr(attr, value)
    case .list(let list):
      if let elem = list.filter({$0.attributes[attr] == value}).first {
        return .Element(elem)
      }
      throw Error.attributeValue(attr: attr, value: value)
    case .Element(let elem):
      if let attr = elem.attributes[attr] {
        if attr == value {
          return .Element(elem)
        }
        throw Error.attributeValue(attr: attr, value: value)
      }
      fallthrough
    default:
      throw Error.attribute(attr: attr)
    }
  }
  
  /**
   Initializes the XMLIndexer
   
   - parameter _: should be an instance of XMLElement, but supports other values for error handling
   - returns: instance of XMLIndexer
   */
  public init(_ rawObject: AnyObject) throws {
    switch rawObject {
    case let value as XMLElement:
      self = .Element(value)
    case let value as LazyXMLParser:
      self = .stream(IndexOps(parser: value))
    default:
      throw Error(instance: rawObject)
    }
  }
  
  public init(_ el: XMLElement) {
    self = .Element(el)
  }
  
  init(_ stream: LazyXMLParser) {
    self = .stream(IndexOps(parser: stream))
  }
  
  /**
   Find an XML element at the current level by element name
   
   - parameter key: The element name to index by
   - returns: instance of XMLIndexer to match the element (or elements) found by key
   - throws: Throws an XMLIndexerError.Key if no element was found
   - TODO: Change to throwing subscripts if available in futher releases
   */
  public func byKey(_ key: String) throws -> XMLIndexer {
    switch self {
    case .stream(let opStream):
      let op = IndexOp(key)
      opStream.ops.append(op)
      return .stream(opStream)
    case .Element(let elem):
      let match = elem.children.filter({ $0.name == key })
      if match.count > 0 {
        if match.count == 1 {
          return .Element(match[0])
        }
        else {
          return .list(match)
        }
      }
      fallthrough
    default:
      throw Error.key(key: key)
    }
  }
  
  /**
   Find an XML element at the current level by element name
   
   - parameter key: The element name to index by
   - returns: instance of XMLIndexer to match the element (or elements) found by
   */
  public subscript(key: String) -> XMLIndexer {
    do {
      return try self.byKey(key)
    } catch let error as Error {
      return .xmlError(error)
    } catch {
      return .xmlError(.key(key: key))
    }
  }
  
  /**
   Find an XML element by index within a list of XML Elements at the current level
   
   - parameter index: The 0-based index to index by
   - returns: instance of XMLIndexer to match the element (or elements) found by key
   - TODO: Change to throwing subscripts if available in futher releases
   */
  public func byIndex(_ index: Int) throws -> XMLIndexer {
    switch self {
    case .stream(let opStream):
      opStream.ops[opStream.ops.count - 1].index = index
      return .stream(opStream)
    case .list(let list):
      if index <= list.count {
        return .Element(list[index])
      }
      return .xmlError(.index(idx: index))
    case .Element(let elem):
      if index == 0 {
        return .Element(elem)
      }
      fallthrough
    default:
      return .xmlError(.index(idx: index))
    }
  }
  
  public subscript(index: Int) -> XMLIndexer {
    do {
      return try byIndex(index)
    }  catch let error as Error {
      return .xmlError(error)
    } catch {
      return .xmlError(.index(idx: index))
    }
  }
  
  typealias GeneratorType = XMLIndexer
  
  public func makeIterator() -> IndexingIterator<[XMLIndexer]> {
    return all.makeIterator()
  }
}

/// XMLIndexer extensions
extension XMLIndexer {
  /// True if a valid XMLIndexer, false if an error type
  public var boolValue: Bool {
    switch self {
    case .xmlError:
      return false
    default:
      return true
    }
  }
}

extension XMLIndexer: CustomStringConvertible {
  public var description: String {
    switch self {
    case .list(let list):
      return list.map { $0.description }.joined(separator: "\n")
    case .Element(let elem):
      if elem.name == rootElementName {
        return elem.children.map { $0.description }.joined(separator: "\n")
      }
      
      return elem.description
    default:
      return ""
    }
  }
}

extension XMLIndexer.Error: CustomStringConvertible {
  public var description: String {
    switch self {
    case .attribute(let attr):
      return "XML Attribute Error: Missing attribute [\"\(attr)\"]"
    case .attributeValue(let attr, let value):
      return "XML Attribute Error: Missing attribute [\"\(attr)\"] with value [\"\(value)\"]"
    case .key(let key):
      return "XML Element Error: Incorrect key [\"\(key)\"]"
    case .index(let index):
      return "XML Element Error: Incorrect index [\"\(index)\"]"
    case .init(let instance):
      return "XML Indexer Error: initialization with Object [\"\(instance)\"]"
    case .error:
      return "Unknown Error"
    }
  }
}

/// Models an XML element, including name, text and attributes
open class XMLElement {
  /// The name of the element
  open let name: String
  /// The inner text of the element, if it exists
  open var text: String?
  /// The attributes of the element
  open var attributes = [String:String]()
  
  var children = [XMLElement]()
  var count: Int = 0
  var index: Int
  
  /**
   Initialize an XMLElement instance
   
   -parameter name: The name of the element to be initialized
   -returns: a new instance of XMLElement
   */
  init(name: String, index: Int = 0) {
    self.name = name
    self.index = index
  }
  
  /**
   Adds a new XMLElement underneath this instance of XMLElement
   
   - parameter name: The name of the new element to be added
   - parameter withAttributes: The attributes dictionary for the element being added
   - returns: The XMLElement that has now been added
   */
  func addElement(_ name: String, withAttributes attributes: NSDictionary) -> XMLElement {
    let element = XMLElement(name: name, index: count)
    count += 1
    
    children.append(element)
    
    for (keyAny,valueAny) in attributes {
      if let key = keyAny as? String,
        let value = valueAny as? String {
          element.attributes[key] = value
      }
    }
    
    return element
  }
}

extension XMLElement: CustomStringConvertible {
  public var description: String {
    var attributesStringList = [String]()
    if !attributes.isEmpty {
      for (key, val) in attributes {
        attributesStringList.append("\(key)=\"\(val)\"")
      }
    }
    
    var attributesString = attributesStringList.joined(separator: " ")
    if !attributesString.isEmpty {
      attributesString = " " + attributesString
    }
    
    if children.count > 0 {
      var xmlReturn = [String]()
      xmlReturn.append("<\(name)\(attributesString)>")
      for child in children {
        xmlReturn.append(child.description)
      }
      xmlReturn.append("</\(name)>")
      return xmlReturn.joined(separator: "\n")
    }
    
    if text != nil {
      return "<\(name)\(attributesString)>\(text!)</\(name)>"
    }
    else {
      return "<\(name)\(attributesString)/>"
    }
  }
}
