'use strict'

###*
 # @ngdoc service
 # @name swarmApp.util
 # @description
 # # util
 # Service in the swarmApp.
###
angular.module('swarmApp').factory 'util', ($log, $rootScope, $timeout) -> new class Util
  constructor: ->
    @memoized = []
  sum: (ns) -> _.reduce ns, ((a,b) -> a+b), 0
  assert: (val, message...) ->
    if not val
      $log.error "Assertion error", message...
      $rootScope.$emit 'assertionFailure', message
      throw new Error message
    return val
  error: (message...) ->
    $rootScope.$emit 'error', message
  walk: (obj, fn, path="", rets=[]) ->
    ret = fn obj, path
    if ret?
      rets.push ret
    if _.isArray obj
      for elem, index in obj
        @walk elem, fn, "#{path}[#{index}]", rets
    else if _.isObject obj
      for key, prop of obj
        @walk prop, fn, "#{path}.#{key}", rets
    return rets
  # For use with lodash _.memoize
  clearMemoCache: (memoizedFns...) ->
    for fn in memoizedFns
      for key, val of fn.cache
        delete fn.cache[key]

  animateController: ($scope, opts={}) ->
    game = opts.game ? $scope.game
    options = opts.options ? $scope.options
    animatePromise = null
    do animateFn = =>
      # timeouts instead of intervals is less precise, but it automatically adjusts to options menu fps changes
      # intervals could work if we watched for options changes, but why bother?
      animatePromise = $timeout animateFn, options.fpsSleepMillis()
      game.tick()
      $rootScope.$emit 'tick', game
    $scope.$on '$destroy', =>
      $timeout.cancel animatePromise

  isWindowFocused: (default_=true) ->
    # true if browser tab focused, false if tab unfocused. NOT 100% RELIABLE! If we can't tell, default == focused (true).
    # err, default != hidden
    return not (document.hidden?() ? not default_)

  memoize: (fn) ->
    ret = _.memoize fn
    @memoized.push ret
    return ret
  clearAllMemoCaches: ->
    @clearMemoCache @memoized
  totalMemoCacheSize: ->
    @sum _.map @memoized, (fn) -> (_.keys fn.cache).length ? 0
