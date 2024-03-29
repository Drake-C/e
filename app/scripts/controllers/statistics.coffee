'use strict'

###*
 # @ngdoc function
 # @name swarmApp.controller:StatisticsCtrl
 # @description
 # # StatisticsCtrl
 # Controller of the swarmApp
###
angular.module('swarmApp').controller 'StatisticsCtrl', ($scope, session, statistics, game, options) ->
  $scope.listener = statistics
  $scope.session = session
  $scope.statistics = session.statistics
  $scope.game = game

  # http://stackoverflow.com/questions/13262621
  utcdoy = (ms) ->
    t = moment.utc(ms)
    "#{parseInt(t.format 'DDD')-1}d #{t.format 'H\\h mm:ss.SSS'}"

  $scope.unitStats = (unit) ->
    ustatistics = _.clone $scope.statistics.byUnit?[unit?.name]
    if ustatistics?
      ustatistics.elapsedFirstStr = utcdoy ustatistics.elapsedFirst
    return ustatistics
  $scope.hasUnitStats = (unit) -> !!$scope.unitStats unit
  $scope.showStats = (unit) -> $scope.hasUnitStats(unit) or (!unit.isBuyable() and unit.isVisible())

  $scope.upgradeStats = (upgrade) ->
    ustatistics = $scope.statistics.byUpgrade[upgrade.name]
    if ustatistics?
      ustatistics.elapsedFirstStr = utcdoy ustatistics.elapsedFirst
    return ustatistics
  $scope.hasUpgradeStats = (upgrade) -> !!$scope.upgradeStats upgrade
