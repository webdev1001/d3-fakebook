'use strict'

class D3Fakebook.LineChart extends D3Fakebook.Chart
  buildChart: ->
    allData = @buildData()
    data  = allData[0]
    dataComparison = allData[1]

    _(allData.length).times (i) =>
      colors = @chartColors
      @_setColorScale colors, allData[i]

    @x = d3.scale.linear()
      .range([0, @innerWidth])

    @y0 = d3.scale.linear()
      .range([@innerHeight, 0])

    @y1 = d3.scale.linear()
      .range([@innerHeight, 0])

    # Set the X and Y axes
    @xAxis = @createAxis 'x', @x, 'bottom'

    @yAxisLeft = @createAxis 'y0', @y0, 'left',
      size :
        major : 0 - @innerWidth
        minor : 0 - @innerWidth
        end   : 0 - @innerWidth

    @yAxisRight = @createAxis 'y1', @y1, 'right'

    countries = @setCountries @color, data
    if dataComparison
      countriesComparison = @setCountries @colorAlt, dataComparison

    xValues  = []
    y0Values = []
    y1Values = []

    # Set domains
    _(data).each (v,k) ->
      _(data[k]).each (d) ->
        xValues.push d[0]
        y0Values.push d[1]

    if dataComparison and dataComparison.length
      _(dataComparison).each(v, k) ->
        _(data[k]).each (d) ->
          y1Values.push d[1]

    @x.domain(d3.extent xValues)
    @setDomain @y0, @findMin(y0Values), @findMax(y0Values)
    @setDomain @y1, @findMin(y1Values), @findMax(y1Values) if dataComparison

    # NOTE: timer is necessary to ensure that the nodes are in the DOM when
    # this event listener is initialized
    setTimeout ->
      $('.data-point').popover
        container : 'body'
        html      : true
        trigger   : 'manual'
        placement : 'top'
      , 10

    @drawChart countries, countriesComparison


  setCountries : (scale, data) ->
    scale.domain().map (name) ->
      name   : name
      values : data[name]

  setDomain : (axis, min, max) ->
    unless min < 0 or min > 10
      min = 0

    axis.domain [min, max]

  createAxis : (plane, scale, position, ticks) ->
    _ticks =
      count     : 10
      subdivide : true
      padding   : 10
      size      : null

    ticks = _.extend _ticks, ticks or {}
    axis = undefined

    if plane is 'x'
      axis = d3.svg.axis()
        .scale(scale)
        .innerTickSize(10)
        .outerTickSize(10)
        .orient(position)

    else if plane.match /^y/
      axis = d3.svg.axis()
        .scale(scale)
        .orient(position)
        .ticks(ticks.count)
        .innerTickSize([ticks.size])
        .outerTickSize([ticks.size])
        .tickPadding(ticks.padding)

      @setTickFormat(axis)

    axis

  findMin : (data) ->
    d3.min data

  findMax : (data) ->
    d3.max data

  drawLines : (dataset, x, y, color, isComparison) ->
    isComparison ||= false

    line = d3.svg.line()
            .defined((d) ->
              if d
                not _.isNaN(d[0]) and not _.isNaN(d[1]))
            .x((d) -> x d[0])
            .y((d) -> y d[1])

    lines = @svg.selectAll('.countries')
                .data(dataset)

    country = lines.enter()
                  .append('g')
                  .attr('class', 'country')

    legendAttr      = "data-legend#{'-comparison' if isComparison}"
    legendColorAttr = 'data-legend-color'

    country.append('path')
          .attr('class', 'line')
          .attr('d', (d) -> line(d.values))
          .attr(legendAttr, (d) -> d.name)
          .attr(legendColorAttr, (d) -> color(d.name))
          .style('stroke', (d) -> color(d.name))
          .style('stroke-dasharray', if isComparison then ('5, 5') else null)

    # Data points
    pointRadius = 5.2
    transitionDuration = 1000
    pointOpacity = 0.4

    pointsGroup = @svg.append('g')
    points = country.selectAll('.data-point').data (d) ->
      filtered = _.filter(d.values, (data) ->
        not _.isNaN(data[0]) and not _.isNaN(data[1]))
      _(filtered).each (f) -> f.push d.name
      filtered

    points.enter()
          .append('circle')
          .attr('class', 'data-point')
          .style('opacity', pointOpacity)
          .attr('cx', (d) -> x d[0])
          .attr('cy', (d) -> y d[1])
          .attr('r', () -> pointRadius)
          .attr('title', (d) ->
            d[2]
          )
          .attr('data-toggle', 'popover')
          .attr('data-content',(d) =>
            "X: #{@utils.round2(d[0])}
            <br />
            Y: #{@utils.round2(d[1])}")
          .style('fill', (d,i) -> color d[2])
          .on('mouseover', (d) ->
            $node = $(this)
            $node.popover('show')

            d3.select(this)
              .transition()
              .duration(250)
              .style('opacity', 1)
          )
          .on('mouseout', (d) ->
            $node = $(this)
            $node.popover('hide')

            d3.select(this)
              .transition()
              .duration(250)
              .style('opacity', pointOpacity)
          )

  drawChart : (data, comparison) ->
    @drawAxes(data, comparison)
    @drawLines(data, @x, @y0, @color)
    @drawLines(comparison, @x, @y1, @colorAlt, true) if comparison
    @drawLegend()
    @drawTitle()

  drawAxes : (data, comparison) ->
    @drawXAxis()
    @drawYAxis()
    @drawYAxis(true) if comparison

  drawXAxis : ->
    @svg.append('g')
      .attr('class', 'x axis')
      .attr('transform', "translate(0, #{@innerHeight})")
      .call(@xAxis)

  drawYAxis : (isSecond) ->
    isSecond ||= false

    y = if isSecond then @y1 else @y0

    xPosition = 0

    if isSecond
      yPosition = @opts.yLabelComparisonOffset or @margin.right / 8
      label = @opts.yLabelComparison
    else
      if @opts.yLabelOffset?
        offset = @opts.yLabelOffset
      else
        offset = @margin.left / 8

      yPosition = 0 - offset
      label = @opts.yLabel

    translation = if isSecond then "translate(#{@innerWidth}, 0)" else null
    labelContentText = label
    #labelContentText = _.str.words(label, ", ")[0]
    #labelContentText += ',' if _.str.words(label, ", ")[1]

    axis = @svg.append('g')
        .attr('class', 'y axis')

    axis.call(if isSecond then @yAxisRight else @yAxisLeft)
        .selectAll('.tick')
        .data(y.ticks(20), (d) -> d)
        .exit()
        .classed('minor', true)
        .attr('transform', translation)

    #axis.selectAll('line')
        #.data(y.ticks(20), (d) -> console.log('d', d); return d)
        #.enter()
        #.append('line')
        #.attr('class', 'minor')
        #.attr('x1', 0)
        #.attr('x2', -@innerWidth)
        #.attr('y1', y)
        #.attr('y2', y)

    labelContent = axis.append('text')
        .attr('transform', "rotate(-90)translate(#{xPosition}, #{yPosition})")
        .style('text-anchor', 'middle')
        .attr('class', 'chart-label chart-label-y-axis')

    labelContent.append('tspan')
        .attr('x', '-160')
        .attr('y', if isSecond then '3.2em' else '-4.2em')
        .text()

    labelContent.append('tspan')
        .attr('x', '-160')
        .attr('y', if isSecond then '4.4em' else '-3.0em')
        .text(label)

  buildData : ->
    _.each @data, (data) ->
      _.map data.data, (d) ->
        d.country = data.country

    dataLabels         = _.compact(_.pluck(@data, 'country'))
    dataLabels         = _.compact(_.pluck(@data, 'name')) unless dataLabels
    datasets           = _.compact(_.flatten(_.pluck(@data, 'data')))
    datasetsComparison = _.compact(_.flatten(_.pluck(@data, 'dataComparison')))

    datasets = _.flatten(datasets)
    countries = _.uniq _.pluck(datasets, 'country')
    data = _.groupBy datasets, (data) ->
      data.country

    parseData = (datasets) ->
      data = undefined
      if datasets and datasets.length
        data = {}
        _(datasets).each (d) ->
          if data[d.country]
            data[d.country].push [d.xValue, d.yValue]
          else
            data[d.country] = [[d.xValue, d.yValue]]

      data

    [parseData(datasets), parseData(datasetsComparison)]
