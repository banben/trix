{elementContainsNode, findChildIndexOfNode, findClosestElementFromNode,
 findNodeFromContainerAndOffset, nodeIsBlockStartComment, nodeIsBlockContainer,
 nodeIsCursorTarget, nodeIsEmptyTextNode, nodeIsTextNode, nodeIsAttachmentElement,
 tagName, walkTree} = Trix

class Trix.LocationMapper
  constructor: (@element) ->

  findLocationFromContainerAndOffset: (container, offset) ->
    childIndex = 0
    foundBlock = false
    location = index: 0, offset: 0

    if attachmentElement = @findAttachmentElementParentForNode(container)
      container = attachmentElement.parentNode
      offset = findChildIndexOfNode(attachmentElement)

    walker = walkTree(@element, usingFilter: rejectAttachmentContents)

    while walker.nextNode()
      node = walker.currentNode

      if node is container and nodeIsTextNode(container)
        unless nodeIsCursorTarget(node)
          location.offset += offset
        break

      else
        if node.parentNode is container
          break if childIndex++ is offset
        else unless elementContainsNode(container, node)
          break if childIndex > 0

        if nodeIsBlockStartComment(node)
          location.index++ if foundBlock
          location.offset = 0
          foundBlock = true
        else
          location.offset += nodeLength(node)

    location

  findContainerAndOffsetFromLocation: (location) ->
    return [@element, 0] if location.index is 0 and location.offset is 0

    [node, nodeOffset] = @findNodeAndOffsetFromLocation(location)
    return unless node

    if nodeIsTextNode(node)
      container = node
      string = node.textContent
      offset = location.offset - nodeOffset

    else
      container = node.parentNode

      unless nodeIsBlockContainer(container)
        while node is container.lastChild
          node = container
          container = container.parentNode
          break if nodeIsBlockContainer(container)

      offset = findChildIndexOfNode(node)
      offset++ unless location.offset is 0

    [container, offset]

  findNodeAndOffsetFromLocation: (location) ->
    offset = 0

    for currentNode in @getSignificantNodesForIndex(location.index)
      length = nodeLength(currentNode)

      if location.offset <= offset + length
        if nodeIsTextNode(currentNode)
          node = currentNode
          nodeOffset = offset
          break if location.offset is nodeOffset and nodeIsCursorTarget(node)

        else if not node
          node = currentNode
          nodeOffset = offset

      offset += length
      break if offset > location.offset

    [node, nodeOffset]

  # Private

  findAttachmentElementParentForNode: (node) ->
    while node and node isnt @element
      return node if nodeIsAttachmentElement(node)
      node = node.parentNode

  getSignificantNodesForIndex: (index) ->
    nodes = []
    walker = walkTree(@element, usingFilter: acceptSignificantNodes)
    recordingNodes = false

    while walker.nextNode()
      node = walker.currentNode
      if nodeIsBlockStartComment(node)
        if blockIndex?
          blockIndex++
        else
          blockIndex = 0

        if blockIndex is index
          recordingNodes = true
        else if recordingNodes
          break
      else if recordingNodes
        nodes.push(node)

    nodes

  nodeLength = (node) ->
    if node.nodeType is Node.TEXT_NODE
      if nodeIsCursorTarget(node)
        0
      else
        string = node.textContent
        string.length
    else if tagName(node) is "br" or nodeIsAttachmentElement(node)
      1
    else
      0

  acceptSignificantNodes = (node) ->
    if rejectEmptyTextNodes(node) is NodeFilter.FILTER_ACCEPT
      rejectAttachmentContents(node)
    else
      NodeFilter.FILTER_REJECT

  rejectEmptyTextNodes = (node) ->
    if nodeIsEmptyTextNode(node)
      NodeFilter.FILTER_REJECT
    else
      NodeFilter.FILTER_ACCEPT

  rejectAttachmentContents = (node) ->
    if nodeIsAttachmentElement(node.parentNode)
      NodeFilter.FILTER_REJECT
    else
      NodeFilter.FILTER_ACCEPT
