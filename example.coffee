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

printQuote()


newTitle = 'Example'
# Get quote data from CNBC
getQuoteCNBC = (tickers) ->
  url = "http://quote.cnbc.com/quote-html-webservice/quote.htm?symbols=#{tickers}&requestMethod=quick&fund=1&noform=1&exthrs=1&extMode=ALL&extendedMask=2&output=json"
  yql = 'http://query.yahooapis.com/v1/public/yql?q=' + encodeURIComponent('select * from html where url="' + url + '"') + '&format=json&callback=?'

  $.getJSON yql, (data) ->
    items = []
    data = $.parseJSON(data.query.results.body.p).QuickQuoteResult.QuickQuote
    change = r2(data.change)
    last = r2(data.last)
    percentChange = Math.round(1e4 * +change / (+last - +change)) / 100
    newTitle = "#{data.symbol}: #{last} #{change} (#{percentChange}%)"

# Example code for ticker box
#$("#ticker_box").html "Ticker box goes here"

# Example code for quote table
$("#quote_table").html "Quote table goes here"

# Example code for putting ticker in title
updateTitle = ->
  ticker = 'SPY'
  getQuoteCNBC ticker
  $(document).attr('title', newTitle)
  tid2 = setTimeout(updateTitle, timeout)

updateTitle()