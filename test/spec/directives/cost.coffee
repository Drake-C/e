'use strict'

describe 'Directive: cost', ->

  # load the directive's module
  beforeEach module 'swarmApp'

  scope = {}

  beforeEach inject ($controller, $rootScope) ->
    scope = $rootScope.$new()

  it 'should make hidden element visible', inject ($compile) ->
    element = angular.element '<cost costlist="[]"></cost>'
    element = $compile(element) scope
    expect(element.text()).toBe ''
