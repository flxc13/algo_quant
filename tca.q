/ Load the data from CSVs
t: ("DSTFF";enlist ",") 0:`$"C:/Users/wicky/Downloads/tca/trade.csv"; t
q: ("DSTFFFF";enlist ",") 0:`$"C:/Users/wicky/Downloads/tca/quote.csv";q
p: ("DSSSITTFF";enlist ",") 0:`$"C:/Users/wicky/Downloads/parent_order.csv";p
c: ("SSDSTFF";enlist ",") 0:`$"C:/Users/wicky/Downloads/child_order.csv";c
t: update time: 09:25 | time&15:00 from t;t

/daily: select DV:sum size, open:first price, close:last price, mooSize: sum size where time<09:30, mocSize:sum size where time>14:57 by date,sym from t1;daily
// Benchmark function
bench:{[benchpx; px; side] 10000 * side * (benchpx - px) % benchpx};
/Calculation functions
Calculation:{[item;t;q;c]
/ Filter trades and quotes for the specific date and sym
t1:select from t where date=item`date, sym=item`sym;
q1:update midpx:0.5*bid+ask from select from q where date=item`date, sym=item`sym;
c1:select from c where date=item`date, sym=item`sym, parentid = item`orderid;
/ Calculate daily volume, opening, and closing prices
d: select DV:sum size, open:first price, close:last price, mooSize: sum size where time<09:30, mocSize:sum size where time>14:57 by date,sym from t1;
/ Calculate average spread during the trading window
d: d,'select spread: avg 10000*(ask-bid)%0.5*ask+bid from q1 where time within (item`starttime;item`endtime);
/ Calculate arrival price
market_open_time: 09:30:00.000;
d: update arrival: first ?[(market_open_time > item`starttime); open; first select last midpx from q1 where time<=item`starttime] from d;
/ Calculate interval VWAP during the trading window
d:d,'select ivwap:size wavg price from t1 where time within (item`starttime;item`endtime);
/ Calculate passive order percentage
c1:update pass: (item`side) * signum (midpx-price)+0.00001 from aj[`time;c;select time,midpx from q1] where time within (09:30;14:57);
d: d,'select notional: sum price*size, sum size, avgpx:size wavg price, sum size, passnum:(sum size where pass=1) from c1 where parentid=item`orderid, time within (09:30;14:57);
d:d,'select pwp5:size wavg price from (update vol5:sums size*0.05 from select from t1 where time>=item`starttime) where vol5 <=item`qty;
d: d,'select avgpx:size wavg price from c where parentid=item`orderid;
/ Add item details to the result
d:(enlist item),'d;
d:update cost_arrival:bench[arrival;avgpx;item`side], 
        cost_ivwap:bench[ivwap;avgpx;item`side], 
        cost_open:bench[open;avgpx;item`side], 
        cost_close:bench[close;avgpx;item`side], 
        cost_pwp5:bench[pwp5;avgpx;item`side] from d;
d: d,'select volo:sum size from c1 where time<09:30, parentid=item`orderid;
d: d,'select volc:sum size from c1 where time>14:57, parentid=item`orderid;
d:update targetpct:qty%DV from d;
d: d,'select exesize:sum size from t1 where time>item`starttime, time<item`endtime;
d: d,'select notional:sum price * size from c where parentid = item`orderid;
d
}
results:raze{[t;q;c;item] Calculation[item;t;q;c] }[t;q;c] each p;results
/generate the TCA analysis table
asm: select OrderID:orderid, Notional:notional%1000000, ADVpct:qty%DV, TradingSpeed:qty%exesize, Spread:spread, cost_open, cost_arrival, cost_ivwap, cost_close, cost_pwp5, mooPct:volo%qty, mocPct:volc%qty, passive:passnum%qty, aggressive:1-((passnum%qty)+(volo%qty)+(volc%qty)) from results;asm
/generate the "All" row
al: select sum Notional, ADVpct: Notional wavg ADVpct, TradingSpeed: Notional wavg TradingSpeed, 
    Spread:Notional wavg Spread, cost_open:Notional wavg cost_open, cost_arrival:Notional wavg cost_arrival, 
    cost_ivwap:Notional wavg cost_ivwap, cost_close:Notional wavg cost_close, cost_pwp5:Notional wavg cost_pwp5, 
    mooPct:Notional wavg mooPct, mocPct:Notional wavg mocPct, passive:Notional wavg passive, aggressive:Notional wavg aggressive from asm;al
al[`OrderID]:`All;
al: `OrderID xcols al;
/merge the "All" row to the table
asm: asm, 1#al;asm
