# JSON Format of Quote Data
The quote data retrived from CNBC or Google Finance are transformed into one
common format.

## Top Level Fields
- tickers: List of tickers that quote data is being return for
  - Ex: ["SPY", "AAPL"]
- <ticker in all caps>: Quote data as structured in the next section

## Quote structure
- last: Most recent price
- last_time: Time the most recent tick occurred (ISO 8601)
- last_time_str: Time the most recent tick occurred (Human readable string: Ex. "Apr 17, 7:59PM EDT")
- open: Opening price
- change: Change from previous close
- change_pct: Change percentage
- name: Full name of ticker
- volume: Volume
- previous_close: Closing price of previous day
- high: Intraday high
- low: Intraday low
- exchange: Name of exchange stock is traded on
- extended: Extended hours quote information with the following fields
  from above:
  - last, last_time, change (from most recent close), change_pct, volume
  - full_change/full_change_pct: Change from previous day's close