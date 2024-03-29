'use strict'

angular.module('swarmApp').factory 'Unit', (util, $log, $compile, Effect) -> class Unit
  # TODO unit.unittype is needlessly long, rename to unit.type
  constructor: (@game, @unittype) ->
    @name = @unittype.name
    @suffix = ''
    @descriptionFn = $compile "<p>#{@unittype.description}</p>"
    @affectedBy = []
    for fn in ['_stats', '_count', '_velocity', '_eachCost']
      @[fn] = util.memoize @[fn]
  _init: ->
    # copy all the inter-unittype references, replacing the type references with units
    @_producerPathList = _.map @unittype.producerPathList, (path) =>
      _.map path, (unittype) =>
        ret = @game.unit unittype
        util.assert ret
        return ret
    @cost = _.map @unittype.cost, (cost) =>
      ret = _.clone cost
      ret.unit = @game.unit cost.unittype
      return ret
    @prod = _.map @unittype.prod, (prod) =>
      ret = _.clone prod
      ret.unit = @game.unit prod.unittype
      return ret
    @prodByName = _.indexBy @prod, (prod) -> prod.unit.name
    @warnfirst = _.map @unittype.warnfirst, (warnfirst) =>
      ret = _.clone warnfirst
      ret.unit = @game.unit warnfirst.unittype
      return ret
    @showparent = @game.unit @unittype.showparent
    @upgrades =
      list: (upgrade for upgrade in @game.upgradelist() when @unittype == upgrade.type.unittype or @showparent?.unittype == upgrade.type.unittype)
    @upgrades.byName = _.indexBy @upgrades.list, 'name'
    @upgrades.byClass = _.groupBy @upgrades.list, (u) -> u.type.class

    @requires = _.map @unittype.requires, (require) =>
      util.assert require.unittype or require.upgradetype, 'unit require without a unittype or upgradetype', @name, name, require
      util.assert not (require.unittype and require.upgradetype), 'unit require with both unittype and upgradetype', @name, name, require
      ret = _.clone require
      if require.unittype?
        ret.resource = ret.unit = util.assert @game.unit require.unittype
      if require.upgradetype?
        ret.resource = ret.upgrade = util.assert @game.upgrade require.upgradetype
      return ret
    @cap = _.map @unittype.cap, (capspec) =>
      ret = _.clone capspec
      ret.unit = @game.unit ret.unittype
      return ret
    @effect = _.map @unittype.effect, (effect) =>
      ret = new Effect @game, this, effect
      ret.unit.affectedBy.push ret
      return ret

    @tab = @game.tabs.byName[@unittype.tab]
    if @tab
      @next = @tab.next this
      @prev = @tab.prev this

  _producerPathData: ->
    _.map @_producerPathList, (path) =>
      tailpath = path.concat [this]
      _.map path, (parent, index) =>
        child = tailpath[index+1]
        # TODO index prod by name?
        prodlink = (prod for prod in parent.prod when prod.unit.name == child.name)
        util.assert prodlink.length == 1
        prodlink = prodlink[0]
        parent:parent
        child:child
        prod:prod

  rawCount: ->
    ret = @game.session.unittypes[@name] ? 0
    if _.isNaN ret
      util.error 'NaN count. oops.', @name, ret
      ret = 0
    return ret
  _setCount: (val) ->
    @game.session.unittypes[@name] = val
    util.clearMemoCache @_count, @_velocity, @_eachCost, @_stats
  _addCount: (val) ->
    @_setCount @rawCount() + val
  _subtractCount: (val) ->
    @_addCount -val

  _gainsPath: (pathdata, secs) ->
    producerdata = pathdata[0]
    gen = pathdata.length
    c = math.factorial gen
    count = producerdata.parent.rawCount()
    # Bonus for ancestor to produced-child == product of all bonuses along the path
    # (intuitively, if velocity and velocity-changes are doubled, acceleration is doubled too)
    # Quantity of buildings along the path do not matter, they're calculated separately.
    bonus = 1
    for ancestordata in pathdata
      val = ancestordata.prod.val + ancestordata.parent.stat 'base', 0
      bonus *= val
      bonus *= ancestordata.parent.stat 'prod', 1
    return count * bonus / c * math.pow secs, gen

  # direct parents, not grandparents/etc. Drone is parent of meat; queen is parent of drone; queen is not parent of meat.
  _parents: ->
    (pathdata[0].parent for pathdata in @_producerPathData() when pathdata[0].parent.prodByName[@name])

  _getCap: ->
    if @hasStat 'capBase'
      ret = @stat 'capBase'
      ret *= @stat 'capMult', 1
      return ret
    #cap = 0
    #for capspec in @cap
    #  capval = capspec.val
    #  if capspec.unit?
    #    capval *= capspec.unit.count()
    #  cap += capval
    #util.assert cap >= 0, 'negative cap', @name, cap
    #return cap
  capValue: (val) ->
    cap = @_getCap()
    if not cap?
      # uncapped
      return val
    if not val?
      # no value supplied - return just the cap
      return cap
    return Math.min val, cap

  capPercent: ->
    if (cap = @capValue())?
      return @count() / cap
  capDurationSeconds: ->
    if (cap = @capValue())?
      count = @count()
      diff = cap - count
      velocity = @velocity()
      return if velocity == 0 then Infinity else diff / velocity
  capDurationMoment: ->
    if (secs = @capDurationSeconds())?
      return moment.duration secs, 'seconds'

  count: -> @_count @game.now.getTime()
  _count: ->
    util.clearMemoCache @_count # store only the most recent count
    secs = @game.diffSeconds()
    count = @rawCount()
    for pathdata in @_producerPathData()
      count += @_gainsPath pathdata, secs
    return @capValue count

  _costMetPercent: ->
    max = Number.MAX_VALUE
    for cost in @eachCost()
      if cost.val > 0
        max = Math.min max, cost.unit.count() / cost.val
    util.assert max >= 0, "invalid unit cost max", @name
    return max

  isVisible: ->
    if @unittype.disabled
      return false
    if @_visible
      return true
    return @_visible = @_isVisible()

  _isVisible: ->
    if @count() > 0
      return true
    util.assert @requires.length > 0, "unit without visibility requirements", @name
    for require in @requires
      if require.val > require.resource.count()
        return false
    return true

  isBuyButtonVisible: ->
    eachCost = @eachCost()
    if @unittype.unbuyable or eachCost.length == 0
      return false
    for cost in eachCost
      if not cost.unit.isVisible()
        return false
    return true

  maxCostMet: (percent=1) ->
    Math.floor @_costMetPercent() * percent

  isCostMet: ->
    @maxCostMet() > 0

  isBuyable: ->
    return @isCostMet() and @isVisible() and not @unittype.unbuyable

  buyMax: (percent) ->
    @buy @maxCostMet percent

  twinMult: ->
    ret = 1
    ret += @stat 'twinbase', 0
    ret *= @stat 'twin', 1
    return ret
  buy: (num=1) ->
    if not @isCostMet()
      throw new Error "We require more resources"
    if not @isBuyable()
      throw new Error "Cannot buy that unit"
    num = Math.min num, @maxCostMet()
    @game.withSave =>
      for cost in @eachCost()
        cost.unit._subtractCount cost.val * num
      twinnum = num * @twinMult()
      @_addCount twinnum
      return {num:num, twinnum:twinnum}

  viewNewUpgrades: ->
    upgrades = @showparent?.upgrades?.list ? @upgrades.list
    for upgrade in upgrades
      upgrade.viewNewUpgrades()
  isNewlyUpgradable: ->
    upgrades = @showparent?.upgrades?.list ? @upgrades.list
    _.some upgrades, (upgrade) ->
      upgrade.isVisible() and upgrade.isNewlyUpgradable()

  totalProduction: ->
    ret = {}
    count = @count()
    for key, val of @eachProduction()
      ret[key] = val * count
    return ret

  eachProduction: ->
    ret = {}
    for prod in @prod
      ret[prod.unit.unittype.name] = (prod.val + @stat 'base', 0) * @stat 'prod', 1
    return ret

  eachCost: -> @_eachCost @game.now.getTime()
  _eachCost: ->
    util.clearMemoCache @_eachCost # store only the most recent
    _.map @cost, (cost) =>
      cost = _.clone cost
      cost.val *= @stat('cost', 1) * @stat("cost.#{cost.unit.unittype.name}", 1)
      return cost

  # speed at which other units are producing this unit.
  velocity: -> @_velocity @game.now.getTime()
  _velocity: ->
    util.clearMemoCache @_velocity # store only the most recent velocity
    sum = 0
    for parent in @_parents()
      prod = parent.totalProduction()
      util.assert prod[@name]?, "velocity: a unit's parent doesn't produce that unit?", @name, parent.name
      sum += prod[@name]
    return sum

  # TODO rework this - shouldn't have to pass a default
  hasStat: (key, default_=undefined) ->
    @stats()[key]? and @stats()[key] != default_
  stat: (key, default_=undefined) ->
    util.assert key?
    ret = @stats()[key] ? default_
    util.assert ret?, 'no such stat', @name, key
    return ret
  stats: -> @_stats @game.now.getTime()
  _stats: ->
    util.clearMemoCache @_stats # store only the most recent
    stats = {}
    schema = {}
    for upgrade in @upgrades.list
      upgrade.calcStats stats, schema
    for uniteffect in @affectedBy
      uniteffect.calcStats stats, schema, uniteffect.parent.count()
    return stats

  statistics: ->
    @game.session.statistics.byUnit[@name] ? {}

  # TODO centralize url handling
  url: ->
    @tab.url this


###*
 # @ngdoc service
 # @name swarmApp.unittypes
 # @description
 # # unittypes
 # Factory in the swarmApp.
###
angular.module('swarmApp').factory 'UnitType', -> class Unit
  constructor: (data) ->
    _.extend this, data
    @producerPath = {}
    @producerPathList = []

  producerNames: ->
    _.mapValues @producerPath, (paths) ->
      _.map paths, (path) ->
        _.pluck path, 'name'

angular.module('swarmApp').factory 'UnitTypes', (spreadsheetUtil, UnitType, util, $log) -> class UnitTypes
  constructor: (unittypes=[]) ->
    @list = []
    @byName = {}
    for unittype in unittypes
      @register unittype

  register: (unittype) ->
    @list.push unittype
    @byName[unittype.name] = unittype

  @_buildProducerPath = (unittype, producer, path) ->
    path = [producer].concat path
    unittype.producerPathList.push path
    unittype.producerPath[producer.name] ?= []
    unittype.producerPath[producer.name].push path
    for nextgen in producer.producedBy
      @_buildProducerPath unittype, nextgen, path

  @parseSpreadsheet: (effecttypes, data) ->
    rows = spreadsheetUtil.parseRows {name:['cost','prod','warnfirst','requires','cap','effect']}, data.data.unittypes.elements
    ret = new UnitTypes (new UnitType(row) for row in rows)
    for unittype in ret.list
      unittype.producedBy = []
      unittype.affectedBy = []
    for unittype in ret.list
      #unittype.tick = if unittype.tick then moment.duration unittype.tick else null
      #unittype.cooldown = if unittype.cooldown then moment.duration unittype.cooldown else null
      # replace names with refs
      if unittype.showparent
        spreadsheetUtil.resolveList [unittype], 'showparent', ret.byName
      spreadsheetUtil.resolveList unittype.cost, 'unittype', ret.byName
      spreadsheetUtil.resolveList unittype.prod, 'unittype', ret.byName
      spreadsheetUtil.resolveList unittype.warnfirst, 'unittype', ret.byName
      spreadsheetUtil.resolveList unittype.requires, 'unittype', ret.byName, {required:false}
      spreadsheetUtil.resolveList unittype.cap, 'unittype', ret.byName, {required:false}
      spreadsheetUtil.resolveList unittype.effect, 'unittype', ret.byName
      spreadsheetUtil.resolveList unittype.effect, 'type', effecttypes.byName
      # oops - we haven't parsed upgradetypes yet! done in upgradetype.coffee.
      #spreadsheetUtil.resolveList unittype.require, 'upgradetype', ret.byName
      for prod in unittype.prod
        prod.unittype.producedBy.push unittype
        util.assert prod.val > 0, "unittype prod.val must be positive", prod
      for cost in unittype.cost
        util.assert cost.val > 0, "unittype cost.val must be positive", cost
    for unittype in ret.list
      for producer in unittype.producedBy
        @_buildProducerPath unittype, producer, []
    $log.debug 'built unittypes', ret
    return ret

###*
 # @ngdoc service
 # @name swarmApp.units
 # @description
 # # units
 # Service in the swarmApp.
###
angular.module('swarmApp').factory 'unittypes', (UnitTypes, effecttypes, spreadsheet) ->
  return UnitTypes.parseSpreadsheet effecttypes, spreadsheet
