const distributionsChart = {
  margin: {top: 50, right: 80, bottom: 50, left: 80},
  colorScale: d3.scaleSequential(d3.interpolateRdYlBu).domain([0,100]),
  width: 700,
  height: 500,

  initialize: function(dataset, container) {
    this.width = container.node().offsetWidth
      - this.margin.left
      - this.margin.right;
    this.height = 600 - this.margin.top - this.margin.bottom;

    this.playersYScale = d3.scaleLinear()
      .domain([0, 8000])
      .range([this.height, 0]);

    this.xIndexRatingMap = d3.scaleLinear()
      .domain([0, 80])
      .range([800, 2800]);

    this.ratingXScale = d3.scaleLinear()
      .domain([800, 2800])
      .range([0, this.width]);

    this.cumulativePercentScale = d3.scaleLinear()
      .domain([0, 1])
      .range([this.height, 0]);

    // 1. Add the SVG to the page and employ #2
    this.svg = d3.select("div.container").append("svg")
        .attr("width", this.width + this.margin.left + this.margin.right)
        .attr("height", this.height + this.margin.top + this.margin.bottom)
      .append("g")
      .attr("transform", "translate("
        + this.margin.left + "," + this.margin.top + ")");

    this.createAxes()
    // this.createCumulativeAxis()
    // this.createRatingAxis()

    this.playersArea = d3.area()
      .x((d, i) => this.ratingXScale(this.xIndexRatingMap(i)))
      .y0(this.height)
      .y1(d => this.playersYScale(d));

    this.playersLine = d3.line()
      .x((d, i) => this.ratingXScale(this.xIndexRatingMap(i)))
      .y(d => this.playersYScale(d));

    this.svg.append('path')
        .datum(dataset)
        .attr('class', 'players line')
        .attr('d', this.playersLine);

    this.svg.append('path')
        .datum(dataset)
        .attr('class', 'players area')
        .attr('d', this.playersArea);


    const cumulative = cumulativeDistribution(dataset);
    const total = cumulative[cumulative.length - 1];

    this.cumulativeYScale = d3.scaleLinear()
      .domain([0, total])
      .range([this.height, 0]);

    let cumulativeLine = d3.line()
      .x((d, i) => this.ratingXScale(this.xIndexRatingMap(i)))
      .y(d => this.cumulativeYScale(d));

    this.svg.append('path')
        .datum(cumulative)
        .attr('class', 'cumulative line')
        .attr('d', cumulativeLine);
  },

  update: function(distribution) {

    this.svg.select('.players.line')
        .datum(distribution)
        .attr('d', this.playersLine);

    this.svg.select('.players.area')
        .datum(distribution)
        .attr('d', this.playersArea);


    const cumulative = cumulativeDistribution(distribution);
    const total = cumulative[cumulative.length - 1];

    this.cumulativeYScale = d3.scaleLinear()
      .domain([0, total])
      .range([this.height, 0]);

    let cumulativeLine = d3.line()
      .x((d, i) => this.ratingXScale(this.xIndexRatingMap(i)))
      .y(d => this.cumulativeYScale(d));

    this.svg.select('.cumulative.line')
        .datum(cumulative)
        .attr('d', cumulativeLine);
  },

  createAxes: function() {
    // 3. Call the x axis in a group tag
    this.svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + this.height + ")")
        .call(d3.axisBottom(this.ratingXScale).ticks(21, 'd')); // Create an axis component with d3.axisBottom

    // text label for the x axis
    this.svg.append("text")
        .attr("transform",
              "translate(" + (this.width/2) + " ," +
                              (this.height + this.margin.top - 10) + ")")
        .attr('class', 'axis-label')
        .style("text-anchor", "middle")
        .text("Rating");


    // Make the "Players" axis
    this.svg.append("g")
        .attr("class", "y axis")
        .call(d3.axisLeft(this.playersYScale).ticks(null, 's'));

    this.svg.append("text")
        .attr("transform", "rotate(-90)")
        .attr("y", 0 - this.margin.left)
        .attr("x",0 - (this.height / 2))
        .attr("dy", "1em")
        .style("text-anchor", "middle")
        .text("Players");

    // Make the cumulative axis
    this.svg.append("g")
        .attr("class", "y axis")
        .attr("transform", "translate(" + this.width + ",0)")
        .call(d3.axisRight(this.cumulativePercentScale).ticks(5, '%'));

    this.svg.append("text")
        .attr("transform", "rotate(90)")
        .attr("y", 0 - this.width - this.margin.right)
        .attr("x", (this.height / 2))
        .attr("dy", "1em")
        .style("text-anchor", "middle")
        .text("Cumulative");
  },
}

function cumulativeDistribution(data) {
  const cumulativeSum = (sum => value => sum += value)(0);
  return data.map(cumulativeSum);
}
