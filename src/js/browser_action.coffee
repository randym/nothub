class Store
  constructor: (@storage)->
    @ee = new EventEmitter

  add: (type, name) ->
    @open type, @storage, (data) ->
      data[name] = {} # TODO add details
    @ee.emit('add', type, name)

  remove: (type, name) ->
    @open type, @storage, (data) ->
      delete data[name]
    @ee.emit('remove', type, name)

  items: (type) ->
    @restore(@storage[type])

  on: (args...) ->
    @ee.on(args...)

  # @api private
  restore: (dataString) ->
    try
      JSON.parse(dataString)
    catch e
      {}

  # @api private
  open: (key, storage, callback) ->
    data = @restore(storage[key])
    callback(data)
    storage[key] = JSON.stringify(data)

background = chrome.extension.getBackgroundPage()
{updateQuery} = background

store = new Store(localStorage)

store.on 'add', updateQuery
store.on 'remove', updateQuery

# for gravatar
loadGravatarIcon = (type, name, callback) ->
  [apiPath, handler] = switch type
    when 'username'
      [
        "users/#{name}"
        (data) -> callback(data.avatar_url)
      ]
    when 'reponame'
      [
        "repos/#{name}"
        (data) -> callback(data.owner.avatar_url)
      ]
  $.ajax
    url: "https://api.github.com/#{apiPath}"
    dataType: 'json'
    success: handler
    error: ->
      callback('../images/404.png')

jQuery ($) ->
  areaFromType = (type) ->
    areas = $('.watchArea').filter (i, el) ->
      $(el).data('type') == type
    areas[0]

  # template for watched name
  # requires: name, type
  toWatchedArea = _.template '''
    <li data-name="<%- name %>">
      <a href="https://github.com/<%- name %>" target="_blank">
        <img class="icon" src="../images/loading.gif" data-name="<%- name %>"/>
      </a>
      <span class="watchedName">
        <a href="https://github.com/<%- name %>" target="_blank">
          <%- name %>
        </a>
      </span>
      <span class="opelation">
        <a href="#" class="deleteWatchedName" data-name="<%- name %>" data-type="<%- type %>">
          [x]
        </a>
      </span>
    </li>
  '''

  addNameToWatchedField = (type, name) ->
    $place = $('.watchedNames', areaFromType(type))
    $field = $(toWatchedArea({type, name}))
    $('img.icon', $field).one 'load', ->
      $img = $(this)
      loadGravatarIcon type, name, (icon) ->
        $img.attr('src', icon)

    $place.append($field)

  store.on 'add', addNameToWatchedField

  removeNameFromWatchedField = (type, name) ->
    $place = $('.watchedNames', areaFromType(type))
    $('li', $place).each (i, el)->
      if $(el).data('name') == name
        $(el).remove()

  store.on 'remove', removeNameFromWatchedField

  $('.watchArea').each (i, area) ->
    type = $(area).data('type')

    # setup submit event
    $('.watchButton', area).click ->
      $field = $('.nameInputField', area)
      name = $field.attr('value')
      name = name.replace(/^ +| +$/g, '') # trim
      return unless name
      store.add(type, name)
      $field.attr('value', '')

    # setup initialize data
    for name, _details of store.items(type)
      addNameToWatchedField(type, name)

  # setup delete link
  $('.watchArea .deleteWatchedName').live 'click', ->
    name = $(this).data('name')
    type = $(this).data('type')
    store.remove(type, name)

  # cancel default submit
  $('.watchArea').submit ->
    false
