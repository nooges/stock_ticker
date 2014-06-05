quoteStr = (last, change, time) ->
  if change > 0
    fontColor = "green"
  else if change < 0
    fontColor = "red"
  else
    fontColor = "black"
  percentChange = Math.round(1e4 * +change / (+last - +change)) / 100
  output = last + " <b>Change:</b> <font color=" + fontColor + ">"
  output += change + " (" + percentChange + "%)</font>"
  output += " (" + time + ")"
  output

# Round to decimal points
r2 = (n) ->
  (+n).toFixed 2

timeout = 5e3
tid = undefined
items = []
months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

# ISO 8601 Parser
((Date, undefined_) ->
  origParse = Date.parse
  numericKeys = [1, 4, 5, 6, 7, 10, 11]
  Date.parse = (date) ->
    timestamp = undefined
    struct = undefined
    minutesOffset = 0
    
    # ES5 §15.9.4.2 states that the string should attempt to be parsed as a Date Time String Format string
    # before falling back to any implementation-specific date parsing, so that¿s what we do, even if native
    # implementations could be faster
    #              1 YYYY                2 MM       3 DD           4 HH    5 mm       6 ss        7 msec        8 Z 9 ±    10 tzHH    11 tzmm
    if struct = /^(\d{4}|[+\-]\d{6})(?:-(\d{2})(?:-(\d{2}))?)?(?:T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{3}))?)?(?:(Z)|([+\-])(\d{2})(?::?(\d{2}))?)?)?$/.exec(date)
      
      # avoid NaN timestamps caused by ¿undefined¿ values being passed to Date.UTC
      i = 0
      k = undefined

      while (k = numericKeys[i])
        struct[k] = +struct[k] or 0
        ++i
      
      # allow undefined days and months
      struct[2] = (+struct[2] or 1) - 1
      struct[3] = +struct[3] or 1
      if struct[8] isnt "Z" and struct[9] isnt `undefined`
        minutesOffset = struct[10] * 60 + struct[11]
        minutesOffset = 0 - minutesOffset  if struct[9] is "+"
      timestamp = Date.UTC(struct[1], struct[2], struct[3], struct[4], struct[5] + minutesOffset, struct[6], struct[7])
    else
      timestamp = (if origParse then origParse(date) else NaN)
    timestamp

  return
) Date

# Convert time to formatted string
datetimeStr = (time) ->
  hours = time.getHours()
  ap = "AM"
  ap = "PM"  if hours > 11
  hours -= 12  if hours > 12
  hours = 12  if hours is 0
  minutes = time.getMinutes()
  minutes = "0" + minutes  if minutes < 10
  months[time.getMonth()] + " " + time.getDate() + ", " + hours + ":" + minutes + ap

# Print quote
printQuote = ->
  d = new Date()
  tickers = "AAPL%7CVXAPL"
  url = "http://quote.cnbc.com/quote-html-webservice/quote.htm?symbols=" + tickers + "&requestMethod=quick&fund=1&noform=1&exthrs=1&extMode=ALL&extendedMask=2&output=json"
  yql = "http://query.yahooapis.com/v1/public/yql?q=" + encodeURIComponent("select * from html where url=\"" + url + "\"") + "&format=json&callback=?"
  
  #$.ajax({url: yql, dataType: 'jsonp text xml'}, function(data)
  $.getJSON yql, (data) ->
    items = []
    data = $.parseJSON(data.query.results.body.p).QuickQuoteResult.QuickQuote
    $.each data, (key, datum) ->
      console.log datum
      time = undefined
      if datum.hasOwnProperty("reg_last_time")
        time = new Date(Date.parse(datum.reg_last_time))
      else
        time = new Date(+datum.last_time_msec)
      output = quoteStr(r2(datum.last), r2(datum.change), datetimeStr(time))
      if datum.symbol is "VXAPL"
        items.push "<b>" + datum.symbol + "</b> " + output
        items.push "<b> Range:</b> " + r2(datum.low) + "-" + r2(datum.high)
      else
        items.push "<b>" + datum.name + " (" + datum.symbol + ")</b> " + output
        
        # If after 4:00pm or before 9:30am
        #var extHours = d.getHours() > 15 || d.getHours() < 9 || (d.getHours() == 9 && d.getMinutes() < 30)
        #if (extHours)
        extHours = false
        extTime = new Date()
        if datum.hasOwnProperty("ExtendedMktQuote")
          if datum.ExtendedMktQuote.hasOwnProperty("afthrs_last_time")
            extTime.setTime Date.parse(datum.ExtendedMktQuote.afthrs_last_time)
          else
            extTime.setTime Date.parse(datum.ExtendedMktQuote.last_time)
          if extTime.getTime() > time.getTime()
            extHours = true
            output = quoteStr(r2(datum.ExtendedMktQuote.last), r2(datum.ExtendedMktQuote.change), datetimeStr(extTime))
            items.push "<br><b>Extended Hours:</b> " + output
        items.push "<br><b>Range:</b> " + r2(datum.low) + "-" + r2(datum.high)
        if extHours
          items.push " <b>Volume/Average/Ext. Hours:</b> " + r2(datum.volume / 1e6) + "M/" + r2(datum.FundamentalData.tendayavgvol) + "M"
          items.push "/" + datum.ExtendedMktQuote.volume
        else
          items.push " <b>Volume/Average:</b> " + r2(datum.volume / 1e6) + "M/" + r2(datum.FundamentalData.tendayavgvol) + "M"
        items.push "<br><b>PE:</b> " + r2(datum.FundamentalData.pe)
        items.push " <b>EPS:</b> " + r2(datum.FundamentalData.eps)
        items.push " <b>Mkt. Cap:</b> " + r2(datum.FundamentalData.mktcap / 1e9) + "B"
        items.push "<br>"
      return

    printAll()
    return

  
  #printVXAPL();
  tid = setTimeout(printQuote, timeout)
  return

printVXAPL = ->
  d = new Date()
  n = d.toTimeString()
  url = "http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.quotes%20where%20symbol%20in%20(%22%5EVXAPL%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=?"
  $.getJSON url, (data) ->
    $.each data.query.results, (key, datum) ->
      items.push "<br>"
      output = quoteStr(datum.LastTradePriceOnly, datum.Change, datum.LastTradeTime)
      items.push "<b>" + datum.symbol + "</b> " + output
      items.push " <b>Range:</b> " + datum.DaysLow + "-" + datum.DaysHigh
      return

    printAll()
    return

  return
printAll = ->
  header = "<center><table border=1><tr><td><font size=3><center>"
  footer = "</center></font></td></tr></table></center>"
  $("#ticker_box").html header + items.join("") + footer
  return

#printQuote()

# Get quote data from Google Finance
getQuotesGoogle = (tickers, callback_func) ->
  # Join ticker symbols together
  tickersStr = tickers.join(',')

  url = "http://www.google.com/finance/info?infotype=infoquoteall&q=#{tickersStr}&callback=?"
  $.getJSON url, (data) ->
    quotes = {}
    quotes['tickers'] = []
    for quote in data
      symbol = quote.t
      quotes['tickers'].push(symbol)
      # Convert quote data to common format
      output = {}
      output['last'] = quote.l
      output['last_time_str'] = quote.lt_dts
      #output['open'] = quote.open
      output['change'] = quote.c
      output['change_pct'] = quote.cp
      output['name'] = quote.t  # To be replaced
      #output['volume'] = quote.volume
      output['previous_close'] = quote.l - quote.c
      #output['high'] = quote.high
      #output['low'] = quote.low
      output['exchange'] = quote.e

      if 'el' of quote
        output['extended'] = {}
        output['extended']['last'] = quote.el
        output['extended']['last_time_str'] = quote.elt
        output['extended']['change'] = quote.ec
        output['extended']['change_pct'] = quote.ecp
        #output['extended']['volume'] = 
        output['extended']['full_change'] = quote.ec + quote.c
        #output['extended']['full_change_pct'] = quote.ecp

      quotes[symbol] = output

    callback_func(quotes)

# Get quote data from CNBC
getQuotesCNBC = (tickers, callback_func) ->
  # Join ticker symbols together
  # Add dummy ticker symbol if there's only one listed so that the quote data
  # from CNBC will be returned as a list instead of being shifted up a level
  if tickers.length == 1
    tickers.push('FAKESYMBOL')
  tickersStr = tickers.join('%7C')

  url = "http://quote.cnbc.com/quote-html-webservice/quote.htm?symbols=#{tickersStr}&requestMethod=quick&fund=1&noform=1&exthrs=1&extMode=ALL&extendedMask=2&output=json"
  yql = 'http://query.yahooapis.com/v1/public/yql?q=' + encodeURIComponent('select * from html where url="' + url + '"') + '&format=json&callback=?'

  $.getJSON yql, (data) ->
    quotes = {}
    quotes['tickers'] = []
    data = $.parseJSON(data.query.results.body.p).QuickQuoteResult.QuickQuote
    for quote in data
      symbol = quote.symbol
      if symbol == 'FAKESYMBOL'
        continue

      quotes['tickers'].push(symbol)
      # Convert quote data to common format
      output = {}
      output['last'] = quote.last
      output['last_time'] = quote.last_time
      output['open'] = quote.open
      output['change'] = quote.change
      output['change_pct'] = quote.change_pct
      output['name'] = quote.name
      output['volume'] = quote.volume
      output['previous_close'] = quote.previous_day_closing
      output['high'] = quote.high
      output['low'] = quote.low
      output['exchange'] = quote.exchange
      if "ExtendedMktQuote" of quote
        extTime = new Date()
        # Check if last_time < extended.last_time first
        if "reg_last_time" of quote
          time = new Date(Date.parse(quote.reg_last_time))
        else
          time = new Date(+quote.last_time_msec)
        if "afthrs_last_time" of quote.ExtendedMktQuote
          extTime.setTime Date.parse(quote.ExtendedMktQuote.afthrs_last_time)
        else
          extTime.setTime Date.parse(quote.ExtendedMktQuote.last_time)
        if extTime.getTime() > time.getTime()
          output['extended'] = {}
          output['extended']['last'] = quote.ExtendedMktQuote.last
          output['extended']['last_time'] = quote.ExtendedMktQuote.last_time
          output['extended']['change'] = quote.ExtendedMktQuote.change
          output['extended']['change_pct'] = quote.ExtendedMktQuote.change_pct
          output['extended']['volume'] = quote.ExtendedMktQuote.volume
          output['extended']['full_change'] = quote.ExtendedMktQuote.full_change
          output['extended']['full_change_pct'] = quote.ExtendedMktQuote.full_change_pct

      quotes[symbol] = output

    callback_func(quotes)

#############################
# Example code for ticker box
#############################
#$("#ticker_box").html "Ticker box goes here"
# TODO: Grab the quote data for AAPL and VXAPL separately, then use certain
# pieces to build ticker box


##############################
# Example code for quote table
##############################
$("#quote_table").html "Quote table goes here"

##########################################
# Example code for putting ticker in title
##########################################
titleUpdateInterval = 2e3   # 2 seconds

# Take the quote data retrieved and create a new window/tab title
updateTitle = (quotes) ->
  # Just grab the first ticker in the list for now
  symbol = quotes.tickers[0]
  quote = quotes[symbol]
  last = r2(quote.last)
  change = r2(quote.change)
  change_pct = r2(quote.change_pct)
  if 'extended' of quote
    ext_last = r2(quote.extended.last)
    ext_change = r2(quote.extended.change)
    ext_change_pct = r2(quote.extended.change_pct)
    newTitle = "#{symbol}: #{ext_last} #{ext_change} (#{ext_change_pct}%),  "
    newTitle = newTitle + "[Close] #{last} #{change} (#{change_pct}%)"
  else
    newTitle = "#{symbol}: #{last} #{change} (#{change_pct}%)"
  $(document).attr('title', newTitle)

titleUpdateJob = ->
  tickers = ['SPY', 'AAPL', 'GOOG']
  tickers = ['SPY']
  #getQuotesCNBC(tickers, updateTitle)
  getQuotesGoogle(tickers, updateTitle)
  tid2 = setTimeout(titleUpdateJob, titleUpdateInterval)

titleUpdateJob()

# TODO List:
# - Reformat CNBC and GF sources into common format
# - Better handling of callbacks
