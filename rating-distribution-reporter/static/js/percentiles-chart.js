const percentilesChart = {

  margin: {top: 50, right: 160, bottom: 50, left: 80},
  colorScale: d3.scaleSequential(d3.interpolateRdYlBu).domain([0,100]),

  initialize: function(dataset, container) {
    this.width = container.node().offsetWidth
      - this.margin.left
      - this.margin.right;
    this.height = 600 - this.margin.top - this.margin.bottom;

    // 1. Add the SVG to the page and employ #2
    this.svg = d3.select("div.container").append("svg")
        .attr("width", this.width + this.margin.left + this.margin.right)
        .attr("height", this.height + this.margin.top + this.margin.bottom)
      .append("g")
      .attr("transform", "translate("
        + this.margin.left + "," + this.margin.top + ")");

    let dateParser = d3.timeParse('%d%m%y%H');
    this.xScale = d3.scaleTime()
      .domain(d3.extent(dataset[0].line, (d) => dateParser(d.date)))
      .range([0, this.width]); // output

    // 6. Y scale will use the randomly generate number
    this.yScale = d3.scaleLinear()
        .domain([800, 2800]) // input
        .range([this.height, 0]); // output



    this.createAxes()
    this.createGrid()
    let percentiles = dataset.map(d => d.percentile).sort((a, b) => b - a)
    this.createLegend(percentiles);
    this.createMouseLines();

    this.line = d3.line()
          // set the x values for the line generator
      .x(d => this.xScale(dateParser(d.date)))
          // set the y values for the line generator
      .y(d => this.yScale(d.rating))

    // 9. Append the path, bind the data, and call the line generator
    //
    let lineElements = this.svg.selectAll('.line')
        .data(dataset)
      .join(enter => enter.append("path"))
        .attr("class", "line") // Assign a class for styling
        .style("stroke", d => this.colorScale(d.percentile))
        .attr('data-percentile', d => d.percentile)
        .attr("d", d => this.line(d.line));

    //  // 12. Appends a circle for each datapoint
    //  svg.selectAll(".dot")
    //      .data(dataset)
    //    .enter().append("circle") // Uses the enter().append() method
    //      .attr("class", "dot") // Assign a class for styling
    //      .attr("cx", function(d) { return xScale(d.date) })
    //      .attr("cy", function(d) { return yScale(d.val) })
    //      .attr("r", 5)
    //        .on("mouseover", function(a, b, c) {
    //                          console.log(a)
    //          this.attr('class', 'focus')
    //                  })
    //        .on("mouseout", function() {  })

    //       .on("mousemove", mousemove);

    //   var focus = svg.append("g")
    //       .attr("class", "focus")
    //       .style("display", "none");

    //   focus.append("circle")
    //       .attr("r", 4.5);

    //   focus.append("text")
    //       .attr("x", 9)
    //       .attr("dy", ".35em");

    //   svg.append("rect")
    //       .attr("class", "overlay")
    //       .attr("width", width)
    //       .attr("height", height)
    //       .on("mouseover", function() { focus.style("display", null); })
    //       .on("mouseout", function() { focus.style("display", "none"); })
    //       .on("mousemove", mousemove);

    //   function mousemove() {
    //     var x0 = x.invert(d3.mouse(this)[0]),
    //         i = bisectDate(data, x0, 1),
    //         d0 = data[i - 1],
    //         d1 = data[i],
    //         d = x0 - d0.date > d1.date - x0 ? d1 : d0;
    //     focus.attr("transform", "translate(" + x(d.date) + "," + y(d.close) + ")");
    //     focus.select("text").text(d);
    //   }
  },

  createAxes: function() {
    // 3. Call the x axis in a group tag
    this.svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + this.height + ")")
        .call(d3.axisBottom(this.xScale)); // Create an axis component with d3.axisBottom

    // text label for the x axis
    this.svg.append("text")
        .attr("transform",
              "translate(" + (this.width/2) + " ," +
                              (this.height + this.margin.top) + ")")
        .attr('class', 'axis-label')
        .style("text-anchor", "middle")
        .text("Date");


    // 4. Call the y axis in a group tag
    this.svg.append("g")
        .attr("class", "y axis")
        .call(d3.axisLeft(this.yScale).tickFormat(d3.format(''))); // Create an axis component with d3.axisLeft

    this.svg.append("text")
        .attr("transform", "rotate(-90)")
        .attr("y", 0 - this.margin.left)
        .attr("x",0 - (this.height / 2))
        .attr("dy", "1em")
        .style("text-anchor", "middle")
        .text("Rating");
  },

  createGrid: function() {
    let make_x_gridlines = () => {
      return d3.axisBottom(this.xScale)
          .ticks(8)
    };
    let make_y_gridlines = () => {
      return d3.axisLeft(this.yScale)
          .ticks(5)
    };

    this.svg.append("g")
        .attr("class","grid")
        .attr("transform","translate(0," + this.height + ")")
        .style("stroke-dasharray",("3,3"))
        .call(make_x_gridlines()
            .tickSize(- this.height)
            .tickFormat("")
        )

    this.svg.append("g")
        .attr("class","grid")
        .style("stroke-dasharray",("3,3"))
        .call(make_y_gridlines()
              .tickSize(-this.width)
              .tickFormat("")
        )
  },

  createLegend: function(percentiles) {

    let legendScale = d3.scalePoint()
      .domain(percentiles)
      .range([this.height/2 - 60, this.height/2 + 60])

    let legend = this.svg.selectAll('.legend')
      .data(percentiles)

    let legendEnter=legend
      .enter()
      .append('g')
        .attr('class', 'legend')
        .attr('id', d => d + '-p')

    legendEnter
      .append('circle')
        .attr('cx', this.width +20)
        .attr('cy', d => legendScale(d))
        .attr('r', 7)
        .style('fill', d => this.colorScale(d));

    legendEnter
      .append('text')
        .attr('x', this.width+35)
        .attr('y', d => legendScale(d))
        .text(d => d + "th");
  },

  createMouseLines: function() {
    // mouse following lines
    const focus = this.svg.append('g').style('display', 'none');
    focus.append('line')
        .attr('id', 'focusLineX')
        .attr('class', 'focusLine')
        .style("stroke-dasharray",("3,3"));
    focus.append('line')
        .attr('id', 'focusLineY')
        .attr('class', 'focusLine')
        .style("stroke-dasharray",("3,3"));

    let self = this;
    this.svg.append('rect')
        .attr('class', 'overlay')
        .attr('width', this.width)
        .attr('height', this.height)
        .on('mouseover', function() { focus.style('display', null); })
        .on('mouseout', function() { focus.style('display', 'none'); })
        .on('mousemove', function() {
            var mouse = d3.mouse(this);
            var x = mouse[0];
            var y = mouse[1];

            focus.select('#focusLineX')
                .attr('x1', x).attr('y1', 0)
                .attr('x2', x).attr('y2', self.height);
            focus.select('#focusLineY')
                .attr('x1', 0).attr('y1', y)
                .attr('x2', self.width).attr('y2', y);
        });
  },

  update: function(dataset) {
    let lineElements = this.svg.selectAll('.line')
        .data(dataset)
      .join(enter => enter.append("path"))
        .attr("class", "line") // Assign a class for styling
        .style("stroke", d => this.colorScale(d.percentile))
        .attr('data-percentile', d => d.percentile)
        .transition()
        .attr("d", d => this.line(d.line));
  }
};
