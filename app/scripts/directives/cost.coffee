'use strict'

###*
 # @ngdoc directive
 # @name swarmApp.directive:cost
 # @description
 # # cost
###
angular.module('swarmApp').directive 'cost', ($log) ->
  restrict: 'E'
  scope:
    costlist: '='
    num: '=?'
    buybuttons: '=?'
    noperiod: '=?'
  template: """
  <span ng-repeat="cost in costlist track by cost.unit.name">
    <span ng-if="!$first && $last"> and </span>
    <a ng-if="isRemainingBuyable(cost)" ng-href="\#{{cost.unit.url()}}?twinnum={{countRemaining(cost)}}">
      {{totalCostVal(cost) | bignum}} {{totalCostVal(cost) == 1 ? cost.unit.unittype.label : cost.unit.unittype.plural}}<!--whitespace
    --></a><span ng-if="!isRemainingBuyable(cost)" ng-class="{costNotMet:!isCostMet(cost)}">
      {{totalCostVal(cost) | bignum}} {{totalCostVal(cost) == 1 ? cost.unit.unittype.label : cost.unit.unittype.plural}}<!--whitespace
    --></span><span ng-if="$last && !noperiod">.</span><span ng-if="!$last && costlist.length > 2">, </span>
  </span>
  """
  link: (scope, element, attrs) ->
    scope.num ?= 1
    scope.totalCostVal = (cost) ->
      cost.val * scope.num
    scope.isCostMet = (cost) ->
      cost.unit.count() >= scope.totalCostVal(cost)
    scope.countRemaining = (cost) ->
      return Math.ceil scope.totalCostVal(cost) - cost.unit.count()
    scope.isRemainingBuyable = (cost) ->
      remaining = scope.countRemaining cost
      # there is a cost remaining that we can't afford, but the remaining units are buyable. Can't necessarily afford them.
      return (remaining > 0 and cost.unit.isBuyable())
