trade:("DSTFF"; enlist ",") 0: `C:/Users/wicky/Downloads/trade_quote_data/trade.csv
quote:("DSTFFFF"; enlist ",") 0: `C:/Users/wicky/Downloads/trade_quote_data/quote.csv
quote: select from quote where (time within (09:30;11:29:59.999)) or (time within (13:00;14:56:59.000));quote

//1
d:select vol: sum size, turnover: sum price*size, open:first price, close:last price by sym,date from trade;d
d:update rtn:-1+close%prev close by sym from d;d
q1:select ADV:avg vol, ADTV:avg turnover ,Volatility:(dev rtn) * sqrt(252) by Stock:sym from d
q1q:update Spread:10000 * (ask - bid) % ((bid + ask) % 2), Quote_Size:0.5*(asize + bsize) by sym from quote;q1q
c:select avg Spread, avg Quote_Size by sym, date from q1q;c
s:select averageSpread_bps: avg Spread, avgQuoteSize: avg Quote_Size by Stock:sym from c;s
q1: q1 lj s;q1

//2
q2trade: select last price, volume: sum size by sym, date, time.minute from trade where sym=`600030.SHSE; q2trade
q2trade: update rtn:-1 + price % prev price by sym, date from q2trade;q2trade
q2trade: update volatility: (dev rtn) * sqrt(240) by sym, 5 xbar minute from q2trade; q2trade
q2t: select last price, sum volume, avg volatility by sym, date, 5 xbar minute from q2trade; q2t
q2t: update volpct: volume % sum volume by sym, date from q2t; q2t
q2q: select spread: avg (10000*(ask-bid))%((ask+bid)*0.5), quoteSize: avg 0.5*(asize + bsize) by sym, 5 xbar time.minute from quote; q2q
q2: q2t lj q2q; q2
q2: select intradayVolatility: avg volatility, avg spread, avg quoteSize, avg volpct by time:minute from q2;q2
