breed [ customer ]
breed [ orders ]
breed [ biz ]
breed [ stockroom ]
breed [ text ]

globals [my-ticks order0 orderN tickN stock0 stockCost backorderCost Parallel? FactoryFirst? custDemand S' DSL EAL DAR NAL PAL]
biz-own [stock backorders supply demand received ordered pending lastExpected lastDemand totCost lastPhase]
;              +---------+   (pending)-     Biz: Order of creation reversed when FactoryFirst? true
;    supply <  |         |  < received |    pos   0   1   2   3   (R W D F)
;    demand >  |         |  > ordered  |    who   0   1   2   3   FactoryFirst? false
;              +---------+            -     who   3   2   1   0   FactoryFirst? true

to setup-globals
  set-default-shape biz "house"          set-default-shape orders "barn"           set NAL 4   
  set-default-shape stockroom "rect"     set-default-shape customer "person"          
  set order0 4       set stock0 12       set orderN 8        set tickN 4
  set my-ticks 0        set stockCost .50   set backorderCost 2.00
  set Parallel? member? "||" PlayStyle   set FactoryFirst? member? "Factory" PlayStyle
  if StopAt > 0 [foreach ["inventory" "cost" "orders"] [set-current-plot ? set-plot-x-range 0 StopAt]]
 
end
to setup
  ca
  setup-globals
  setup-biz
  setup-customer
  setup-stockrooms
  setup-patches
  setup-orders
  ask turtles [set label-color black]
end
to setup-biz
  create-biz 4 [
    ifelse FactoryFirst? [setxy (9 - who * 6) 0] [setxy (-9 + who * 6) 0] ;(bizx0 +/- who * bizdx) 0
    set size 5         set color item pos who [gray lime sky red]
    set totCost 0      set stock stock0    set backorders 0    set lastExpected order0    set lastDemand order0
    ifelse Parallel? and not factory? [set pending order0 * 4] [set pending order0 * 3]
    create-label item pos who [["Retailer" .4] ["Wholesaler" .9] ["Distributor" .9] ["Factory" .4]]
    set lastPhase phase
  ]
end
to setup-stockrooms
  ask biz [
    hatch 1 [
      set breed stockroom    setxy xcor ycor - 3
      ask myself [update-stockroom]  ]   ]
end
to setup-patches
  ask patches [set pcolor gray + 4]
  (foreach [2 2 -2 -2] [1 -1 1 -1] [ask biz[ask patch-at ?1 ?2 [set pcolor gray]]])
  ask factory [ask patch-at 3 0 [set pcolor gray]]
end
to setup-orders
  (foreach [2 2 -2 -2] [1 -1 1 -1] [ask biz[setup-order order0 ?1 ?2]])
  ask factory [setup-order order0 3 0]
  ask retailer [ask order -2 1 [die] ask order -2 -1 [die]]
  if not Parallel? [
    ifelse FactoryFirst?
      [ask biz [if not retailer? [ask order -2  1 [die]]]]
      [ask biz [if not factory?  [ask order  2 -1 [die]]]]
  ]
end
to setup-order [quantity deltax deltay]
  setup-colored-order quantity deltax deltay yellow
end
to setup-customer
  ask retailer [
    hatch 1 [
      set breed customer setxy xcor - 4 ycor
      set size 2         set color gray      set label ""  ]  ]
end

; Simulation action
to go
  set my-ticks my-ticks + 1
  ask customer [process-customer]
  ifelse Parallel?
    [ask biz [process-player]]  [foreach [0 1 2 3] [ask turtle ? [process-player]]]
  plot-inventory
  plot-cost
  plot-orders
  plot-phase
  if my-ticks = StopAt [stop]
end

; Ordering proceedures
to process-player
    if OrderFirst? [calculate-ordered]
    refresh-stock
    process-demand
    if not OrderFirst? [calculate-ordered]
    place-orders
    set totCost totCost + cost      ; total cost for this turtle
end
to process-customer
  if my-ticks > 1 [ask order 2 1 [setxyrel -2 -2]]
  calculate-customer-demand
  setup-order ifelse-value (my-ticks > tickN) [custDemand] [order0] 2 -1
end
to refresh-stock
  set received [ label ] of order 2 1
  ask order 2 1 [setxyrel -2 0] ;killorder]
  ifelse factory?
    [ask order 3 0 [setxyrel -1 1] ask order 2 -1 [setxyrel 1 1]]
    [ask order 4 1 [setxyrel -2 0]]
  set pending pending - received
  set stock stock + received
  update-stockroom
end
to process-demand
  set demand [ label ] of order -2 -1
  ask order -2 -1 [setxyrel 2 0] ;killorder]
  if order -4 -1 != nobody [ask order -4 -1 [setxyrel 2 0]]
  set backorders backorders + demand
  set supply min list stock backorders
  set stock stock - supply
  set backorders backorders - supply
  update-stockroom
  ifelse backorders = 0 [setup-order supply -2 1] [setup-colored-order supply -2 1 red]
end
to place-orders
  setup-order ordered 2 -1
  set pending pending + ordered
end

; customer demand calculation
to calculate-customer-demand
  set custDemand ifelse-value (my-ticks > tickN) [runresult (word "calculate-" DemandStyle)] [order0]
end
to-report calculate-Constant report order0 end
to-report calculate-Step    report orderN  end
to-report calculate-Square  report orderN * (floor ((my-ticks - tickN) / 26) mod 2) end
to-report calculate-Sine    report round ((orderN / 2) * (1 + sin (360 * (my-ticks - tickN) / 52))) end
to-report calculate-Random  report random (orderN + 1) end

; "ordered" calculation
to calculate-ordered
  set ordered ifelse-value (my-ticks > tickN) [max list 0 runresult (word "calculate-" OrderStyle)] [order0]
end
to-report calculate-StockGoal report stock0 + order0 - inventory - round (pending / 3) end
to-report calculate-Customer  report [demand] of retailer end; REMIND: fix .. ask the customer
to-report calculate-Sterman
  let expected 0
  let indicated 0
  
  ifelse Visibility 
    [set expected ifelse-value OrderFirst? [[label] of order -2 -1][demand]] 
    [set expected theta * lastDemand + (1 - theta) * lastExpected]
  ifelse WhiteNoise   
    [set indicated expected + alpha * (Q - inventory - beta * pending) + (Random-normal 0 SD)]
    [set indicated expected + alpha * (Q - inventory - beta * pending)]
  set lastDemand demand
  set lastExpected max list 0 round expected
  report round indicated
end

to-report calculate-Phantom
  let expected 0
  let indicated 0
  
    ifelse Visibility 
    [set expected ifelse-value OrderFirst? [[label] of order -2 -1][demand]] 
    [set expected theta * lastDemand + (1 - theta) * lastExpected]
  
  ifelse [ label ] of order 2 1 > 0  
  [set PAL max list NAL (pending / [ label ] of order 2 1)]
  [set PAL NAL ] 
  set EAL (W * NAL + (1 - W) * PAL)
  set DAR expected * alpha * ( DesiredInventory - Inventory)
  set DSL (EAL * DAR) 
  set S' (DesiredInventory + beta * DSL)

  ifelse WhiteNoise   
    [set indicated expected + alpha * (S' - inventory - beta * pending) + (Random-normal 0 SD)]
    [set indicated expected + alpha * (S' - inventory - beta * pending)]
  set lastDemand demand
  set lastExpected max list 0 round expected
  report round indicated
end

to-report calculate-RP
  let expected 0
  let indicated 0
  
    ifelse Visibility 
    [set expected ifelse-value OrderFirst? [[label] of order -2 -1][demand]] 
    [set expected theta * lastDemand + (1 - theta) * lastExpected]
  
  ifelse [ label ] of order 2 1 > 0  
  [set PAL max list NAL (pending / [ label ] of order 2 1)]
  [set PAL NAL ] 
  set EAL (W * NAL + (1 - W) * PAL)
  set DAR expected * alpha * ( DesiredInventory - Inventory)
  set DSL (EAL * DAR) 
  set S' (DesiredInventory + beta * DSL)

  ifelse retailer? [
  ifelse WhiteNoise   
    [set indicated expected + alpha * (S' - inventory - beta * pending) + (Random-normal 0 SD)]
    [set indicated expected + alpha * (S' - inventory - beta * pending)] ]
  [  ifelse WhiteNoise   
    [set indicated expected + alpha * (Q - inventory - beta * pending) + (Random-normal 0 SD)]
    [set indicated expected + alpha * (Q - inventory - beta * pending)]
  ]
    
    
  set lastDemand demand
  set lastExpected max list 0 round expected
  report round indicated
end

to-report calculate-FP
  let expected 0
  let indicated 0
  
    ifelse Visibility 
    [set expected ifelse-value OrderFirst? [[label] of order -2 -1][demand]] 
    [set expected theta * lastDemand + (1 - theta) * lastExpected]
  
  ifelse [ label ] of order 2 1 > 0  
  [set PAL max list NAL (pending / [ label ] of order 2 1)]
  [set PAL NAL ] 
  set EAL (W * NAL + (1 - W) * PAL)
  set DAR expected * alpha * ( DesiredInventory - Inventory)
  set DSL (EAL * DAR) 
  set S' (DesiredInventory + beta * DSL)

  ifelse factory? [
  ifelse WhiteNoise   
    [set indicated expected + alpha * (S' - inventory - beta * pending) + (Random-normal 0 SD)]
    [set indicated expected + alpha * (S' - inventory - beta * pending)] ]
  [  ifelse WhiteNoise   
    [set indicated expected + alpha * (Q - inventory - beta * pending) + (Random-normal 0 SD)]
    [set indicated expected + alpha * (Q - inventory - beta * pending)]
  ]
    
    
  set lastDemand demand
  set lastExpected max list 0 round expected
  report round indicated
end






; Plotting
to plot-inventory
  set-current-plot "inventory"
  (foreach ["R" "W" "D" "F"] [0 1 2 3] [set-current-plot-pen ?1 ask turtle pos ?2 [plot inventory]])
  set-current-plot-pen "0" plot 0
end
to plot-cost
  set-current-plot "cost"
  (foreach ["R" "W" "D" "F"] [0 1 2 3] [set-current-plot-pen ?1 
    ask turtle pos ?2 [plot ifelse-value TotalCost? [totCost] [cost] ]])
end
to plot-orders
  set-current-plot "orders"
  (foreach ["R" "W" "D" "F"] [0 1 2 3] [set-current-plot-pen ?1 plot [ordered] of turtle pos ?2])
  set-current-plot-pen "C" ask retailer [plot demand]
end
to plot-phase
  set-current-plot "PhasePlot"
  (foreach ["R" "W" "D" "F"] [0 1 2 3] 
  [set-current-plot-pen ?1 ask turtle pos ?2[plotxy phase lastPhase set lastPhase phase]])
end

; Biz Utilities
to-report retailer?      report self = retailer end
to-report retailer       report turtle ifelse-value FactoryFirst? [3][0] end
to-report factory?       report self = factory end
to-report factory        report turtle ifelse-value FactoryFirst? [0][3] end
to-report pos [i]        report ifelse-value FactoryFirst? [3 - i][i] end
to-report inventory      report stock - backorders end
to-report cost           report (stock * stockCost) + (backorders * backorderCost) end
to-report phase          report run-result phaseVariable end
to update-stockroom
  let sr 0
  
  set sr one-of stockroom-at 0 -3
  ask sr [
    set label [ inventory ] of myself
    set color ifelse-value ([ inventory ] of myself < 0) [red][yellow]
  ]
end
to create-label [l]
  hatch 1 [
    set breed text     set shape "rect"    set size 1
    setxy xcor + item 1 l ycor             set label item 0 l  ]
end

; Order Utilities
to setup-colored-order [quantity deltax deltay ocolor]
  let neworder 0
  
  set neworder order 0 deltay
  if neworder = nobody [
    hatch 1 [
      set neworder self  set breed orders    set size 1
      set ycor ycor + deltay ] ];if my-ticks > 0 [show who]  ]
  ask neworder [
    set color ocolor
    set label quantity
    setxyrel deltax 0  ]
end
to setxyrel [deltax deltay]
  if slowMo? and my-ticks > 0 [without-interruption [wait 0.25]]
  setxy xcor + deltax ycor + deltay
  set heading 90 - (ycor + 1) * 90
end
to-report order [deltax deltay]
  report one-of orders-at deltax deltay
end

; Misc utilities
to-report TotalCost report reduce [?1 + ?2] [totCost] of biz end


@#$#@#$#@
GRAPHICS-WINDOW
227
10
817
301
14
6
20.0
1
10
1
1
1
0
1
1
1
-14
14
-6
6
0
0
1
ticks

BUTTON
6
79
72
112
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
78
79
144
112
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL

MONITOR
153
254
220
299
NIL
my-ticks
3
1
11

PLOT
0
305
225
567
inventory
tick
inventory
0.0
100.0
0.0
10.0
true
true
PENS
"R" 1.0 0 -16777216 true
"W" 1.0 0 -14835848 true
"D" 1.0 0 -13345367 true
"F" 1.0 0 -2674135 true
"0" 1.0 0 -7500403 true

PLOT
447
364
644
566
cost
ticks
cost
0.0
100.0
0.0
10.0
true
true
PENS
"R" 1.0 0 -16777216 true
"W" 1.0 0 -14835848 true
"D" 1.0 0 -13345367 true
"F" 1.0 0 -2674135 true

CHOOSER
336
574
428
619
OrderStyle
OrderStyle
"Sterman" "StockGoal" "Customer" "Phantom" "RP" "FP"
3

PLOT
223
305
448
567
orders
ticks
orders
0.0
100.0
0.0
10.0
true
true
PENS
"R" 1.0 0 -16777216 true
"W" 1.0 0 -14835848 true
"D" 1.0 0 -13345367 true
"F" 1.0 0 -2674135 true
"C" 1.0 0 -7500403 true

SLIDER
431
574
527
607
alpha
alpha
0
1
0.32
0.01
1
NIL
HORIZONTAL

SLIDER
532
574
625
607
beta
beta
0
1
0.08
0.01
1
NIL
HORIZONTAL

SLIDER
629
575
723
608
theta
theta
0
1
0.38
0.01
1
NIL
HORIZONTAL

SLIDER
729
576
821
609
Q
Q
0
30
10
1
1
NIL
HORIZONTAL

SWITCH
127
574
238
607
OrderFirst?
OrderFirst?
1
1
-1000

SWITCH
5
212
97
245
SlowMo?
SlowMo?
1
1
-1000

SLIDER
106
213
210
246
StopAt
StopAt
0
1040
104
52
1
NIL
HORIZONTAL

BUTTON
148
80
211
113
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

CHOOSER
239
574
333
619
PlayStyle
PlayStyle
"RetailerFirst" "FactoryFirst" "||RetailerFirst" "||FactoryFirst"
0

CHOOSER
104
163
210
208
DemandStyle
DemandStyle
"Step" "Sine" "Square" "Random" "Constant"
4

MONITOR
76
254
149
299
AvgCost
TotalCost / my-ticks
2
1
11

SWITCH
5
163
100
196
Visibility
Visibility
1
1
-1000

MONITOR
5
254
72
299
Cost
reduce [?1 + ?2] [cost] of biz
2
1
11

TEXTBOX
5
143
207
161
These can be changed while running.
11
0.0
0

TEXTBOX
8
10
217
66
Click setup to initialize, go for continuous, step for just one cycle.  Use SlowMo for slow motion and  Visibility for demand certainty.
11
0.0
0

TEXTBOX
5
573
124
614
Expert controls.  Can change while running.
11
0.0
0

PLOT
644
364
832
566
PhasePlot
Time T
Time T-1
0.0
10.0
0.0
10.0
true
true
PENS
"R" 1.0 0 -16777216 true
"W" 1.0 0 -13840069 true
"D" 1.0 0 -13345367 true
"F" 1.0 0 -2674135 true

CHOOSER
668
315
806
360
PhaseVariable
PhaseVariable
"Inventory" "Cost" "Pending" "Ordered" "Received" "Supply" "Demand"
1

SWITCH
485
327
608
360
TotalCost?
TotalCost?
1
1
-1000

SWITCH
837
10
962
43
WhiteNoise
WhiteNoise
1
1
-1000

SLIDER
837
55
1009
88
SD
SD
0
5
1.11
0.01
1
NIL
HORIZONTAL

SLIDER
870
587
1042
620
DesiredInventory
DesiredInventory
0
50
9.9
0.1
1
NIL
HORIZONTAL

SLIDER
867
526
1039
559
W
W
0
1
0.64
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
WHAT IS IT?
-----------
An agent based model of John Sterman's Beer Game.  The beer game studies irrational decision behavior induced by delays in supply chain management.  It uses a board game and cards to simulate the supply chain flow. See ref [5].

HOW IT WORKS
------------
The supply chain consists of four components (suppliers): retailer, wholesaler, distributor and factory.  The customer makes an order to the retailer.  The retailer (and the rest of the supply chain in turn) performs these tasks:
  1 - Get new stock from previous pending orders (variable name: received)
  2 - Get new requests for beer from downstream  (variable name: demand)
  3 - Supply beer for the request and backorders (variable name: supply)
  4 - Make an upstream order based on inventory  (variable name: ordered)
<pre>
Thus:          +---------+
     supply <  |         |  < received
               |         |              [pending]
     demand >  |         |  > ordered
               +---------+
</pre>
It takes one time slot (1 week) for an order to be received by the upstream supplier, and two time slots (2 weeks) for an order to be filled by that supplier, thus a three week lag in all.  These pending orders are remembered by each agent (variable name: pending).

Scoring is done by cost: Inventory cost is stock on hand * $0.50, but backorder cost (when you cannot supply enough thus have the demand unfulfilled, carrying over to the next move) is more expensive: $2.00 per unfulfilled request.

Each supplier shows its inventory in a box just below its building.  It turns red when the inventory is negative, showing the existance of backorders.  Similarly, supplied orders are red if they are part of the backorder .. i.e. are less than the requested number of cases of beer.

HOW TO USE IT
-------------
Clicking on "setup" initializes the game with all players having the same inventory: 12 cases of beer, and the same pipeline of 3 * 4 orders pending.

The customer orders 4 cases each week for four weeks.  This lets the game settle into an equilibrium.  The 5th order goes to 8 cases and stays there for the rest of the game, generally a year (54 ticks) or two (108 ticks)

The key of the game is to successfully manage volitility: variations in demand.

Three monitors show the values for cost, average cost, and the current tick.  The cost is the sum of the four supplier's cost for this tick.  The average keeps a sum of this cost for all ticks and divides by the tick count.

The three main plots show the inventory, orders and cost for each of the suppliers, color coded to be the same color as the supplier in the model.  The inventory plot shows a zero line to show the times of backorder vs healthy inventory, while the orders plot includes the customer order.

The cost plot can show either the current cost, showing the cost volatility, or the total cost, showing the expense so far of the run. This is controled by the switch just above the plot. The final plot is a phase plot (value for a given variable, at time T and T-1), which can plot any of several variables, chosen by a menu just above the plot.

Sterman discovered a formula which matches human behavior, which the game implements.  Note the game does not try to optimize the supply chain!  Instead the purpose of the model is to mimic human behavior and attempt to help it, in this case by increased knowledge down the supply chain (visibility).  Other aids to human reasoning can easily be added.

THINGS TO NOTICE
----------------
The key surprise here is the extreme volatility and lack of convergence to steady state for certain of the parameter settings.  This is achieved with no random choices in the model at all, it is entirely deterministic.  It has been called the Bull Whip Effect [2] and is well documented in management and control studies.

THINGS TO TRY
-------------
First, simply click setup and go, noticing the volatility for these parameter settings. The model stops after a bit .. click go again, and it will go on indefinitely.

Notice the inventory and supply change to red when the supplier cannot fill an order.

There are four controls just under the setup/go/step buttons, explained below.  For now, rerun the model with Visibility switched to "on".  Note the volatility is removed. Now change visibility back to "off" and try a Demand Style of square, then sign.  Note the difference in average cost for the two.  Then try random Demand Style.  Any surprises?! Finally try SlowMo? set "on".  You can toggle it any time during the run.

Visibility: This is a true/false switch which normally is false.  Make a run (setup & go) with it set to true to see how adding a small amount of knowledge reduces the volatility.  In this case, we simply let each supplier know what the upcoming demand will be when calculating the next order to make.

Demand Style: This is simply a way to try customer demand other than the usual step function. Sine and Square vary the demand over a 52 week period, min of 0 and max of 8, thus can be thought of as seasonal variation.  Random simply chooses random numbers between 0 and 8.

SlowMo?: A true/false switch which will slow down each order event enough to be visible. Sorta interesting to see panic build!

StopAt: This makes it easy to stop at a particular point.  Set to be in increments of 52 ticks (year intervals).

EXTENDING THE MODEL
-------------------
The current help for the suppliers is to provide "visibility", simulating increased knowledge provided by the internet or by RFID tags.  Think of other aids and insert them into the model, mainly changing the ordering strategy in simple human ways.  Remember the idea is NOT to optimize the supply chain, but to help the human decision making process.

NETLOGO FEATURES
----------------
This model was initially done in RePast, using work done in The Beer Dock [4].  This was later used by the Santa Fe Institute's Business Network Value Network project [3]. Also see: http://backspaces.net/SCSim/

I decided to rebuild the model in NetLogo to better simulate the actual board game used by Sterman. This was prompted by submitting a paper [1] to the Self-Star workshop on self organization, see http://www.cs.unibo.it/self-star/

The "physicality" of NetLogo exposed interesting issues that had been noted by earlier simulations.  One example is that the orders are actually spacially arranged in both the board game and in the NetLogo simulation. But in some earlier investigations, the orders were kept in queues which could be of variable length.  These sometimes violated the rules of the board game by having too many items in the queues during part of the play.  NetLogo nicely enables simulation of the actual physical board game itself.

A second reason to use NetLogo was work done by Complexity Workshop, urging RePast and NetLogo to be used as synergistic tools, rather than either/or choices.  Basically, NetLogo is wonderful for quick "what if" questions during the early phase of designing complex models, while RePast, with its access to GIS, CAD, 3D etc packages is appropriate for extremely complicated models.  We like to say that, in NetLogo, you think more about modeling than programming, while the reverse is true in RePast.  Both are important at different phases of projects.  Thus I was interested to see how far I could get in NetLogo and was delighted to see the basic game and visibility assist were both quite easily done, while the Mesh Network assist done in RePast might have proven difficult.

RELATED MODELS
--------------
See references, and the web, searching for the Beer Game.

CREDITS AND REFERENCES
----------------------
[1] Densmore, O. The Emergence of Stability in Diverse Supply Chains. SELF-STAR: International Workshop on Self-* Properties in Complex Information Systems, June 2004.

[2] Lee, H.L., Padmanabhan, V. and Whang, S.  The Bullwhip Effect in Supply Chains. Sloan Management Review, pages 93--102, 1997.

[3] Macal, North, MacKerrow, Danner, Densmore, Kim. Information Visibility and Transparency in Supply Chains. Lake Arrowhead Conference on Human Complex Systems, March 2003.

[4] North, M.J., Macal, C.M. The Beer Dock: Three and a Half Implementations of the Beer Distribution Game. SwarmFest 2002.

[5] Sterman, J.D. Modeling Managerial Behavior: Misperceptions of Feedback in a Dynamic Decision Making Experiment. Management Science, 35(3), 321-339, 1988.

@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

ant
true
0
Polygon -7500403 true true 136 61 129 46 144 30 119 45 124 60 114 82 97 37 132 10 93 36 111 84 127 105 172 105 189 84 208 35 171 11 202 35 204 37 186 82 177 60 180 44 159 32 170 44 165 60
Polygon -7500403 true true 150 95 135 103 139 117 125 149 137 180 135 196 150 204 166 195 161 180 174 150 158 116 164 102
Polygon -7500403 true true 149 186 128 197 114 232 134 270 149 282 166 270 185 232 171 195 149 186
Polygon -7500403 true true 225 66 230 107 159 122 161 127 234 111 236 106
Polygon -7500403 true true 78 58 99 116 139 123 137 128 95 119
Polygon -7500403 true true 48 103 90 147 129 147 130 151 86 151
Polygon -7500403 true true 65 224 92 171 134 160 135 164 95 175
Polygon -7500403 true true 235 222 210 170 163 162 161 166 208 174
Polygon -7500403 true true 249 107 211 147 168 147 168 150 213 150

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

barn
true
0
Polygon -7500403 true true 150 3 30 63 31 259 270 259 270 61

bee
true
0
Polygon -1184463 true false 152 149 77 163 67 195 67 211 74 234 85 252 100 264 116 276 134 286 151 300 167 285 182 278 206 260 220 242 226 218 226 195 222 166
Polygon -16777216 true false 150 149 128 151 114 151 98 145 80 122 80 103 81 83 95 67 117 58 141 54 151 53 177 55 195 66 207 82 211 94 211 116 204 139 189 149 171 152
Polygon -7500403 true true 151 54 119 59 96 60 81 50 78 39 87 25 103 18 115 23 121 13 150 1 180 14 189 23 197 17 210 19 222 30 222 44 212 57 192 58
Polygon -16777216 true false 70 185 74 171 223 172 224 186
Polygon -16777216 true false 67 211 71 226 224 226 225 211 67 211
Polygon -16777216 true false 91 257 106 269 195 269 211 255
Line -1 false 144 100 70 87
Line -1 false 70 87 45 87
Line -1 false 45 86 26 97
Line -1 false 26 96 22 115
Line -1 false 22 115 25 130
Line -1 false 26 131 37 141
Line -1 false 37 141 55 144
Line -1 false 55 143 143 101
Line -1 false 141 100 227 138
Line -1 false 227 138 241 137
Line -1 false 241 137 249 129
Line -1 false 249 129 254 110
Line -1 false 253 108 248 97
Line -1 false 249 95 235 82
Line -1 false 235 82 144 100

bird1
false
0
Polygon -7500403 true true 2 6 2 39 270 298 297 298 299 271 187 160 279 75 276 22 100 67 31 0

bird2
false
0
Polygon -7500403 true true 2 4 33 4 298 270 298 298 272 298 155 184 117 289 61 295 61 105 0 43

boat1
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 158 33 230 157 182 150 169 151 157 156
Polygon -7500403 true true 149 55 88 143 103 139 111 136 117 139 126 145 130 147 139 147 146 146 149 55

boat2
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 157 54 175 79 174 96 185 102 178 112 194 124 196 131 190 139 192 146 211 151 216 154 157 154
Polygon -7500403 true true 150 74 146 91 139 99 143 114 141 123 137 126 131 129 132 139 142 136 126 142 119 147 148 147

boat3
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 158 37 172 45 188 59 202 79 217 109 220 130 218 147 204 156 158 156 161 142 170 123 170 102 169 88 165 62
Polygon -7500403 true true 149 66 142 78 139 96 141 111 146 139 148 147 110 147 113 131 118 106 126 71

box
true
0
Polygon -7500403 true true 45 255 255 255 255 45 45 45

butterfly1
true
0
Polygon -16777216 true false 151 76 138 91 138 284 150 296 162 286 162 91
Polygon -7500403 true true 164 106 184 79 205 61 236 48 259 53 279 86 287 119 289 158 278 177 256 182 164 181
Polygon -7500403 true true 136 110 119 82 110 71 85 61 59 48 36 56 17 88 6 115 2 147 15 178 134 178
Polygon -7500403 true true 46 181 28 227 50 255 77 273 112 283 135 274 135 180
Polygon -7500403 true true 165 185 254 184 272 224 255 251 236 267 191 283 164 276
Line -7500403 true 167 47 159 82
Line -7500403 true 136 47 145 81
Circle -7500403 true true 165 45 8
Circle -7500403 true true 134 45 6
Circle -7500403 true true 133 44 7
Circle -7500403 true true 133 43 8

circle
false
0
Circle -7500403 true true 35 35 230

house
false
0
Polygon -7500403 true true 151 18 15 150 60 150 60 286 242 286 242 152 287 152

line
true
0
Line -7500403 true 150 0 150 301

person
false
0
Circle -7500403 true true 155 20 63
Rectangle -7500403 true true 158 79 217 164
Polygon -7500403 true true 158 81 110 129 131 143 158 109 165 110
Polygon -7500403 true true 216 83 267 123 248 143 215 107
Polygon -7500403 true true 167 163 145 234 183 234 183 163
Polygon -7500403 true true 195 163 195 233 227 233 206 159

rect
false
0
Rectangle -7500403 true true 46 123 254 179

sheep
false
15
Rectangle -1 true true 90 75 270 225
Circle -1 true true 15 75 150
Rectangle -16777216 true false 81 225 134 286
Rectangle -16777216 true false 180 225 238 285
Circle -16777216 true false 1 88 92

spacecraft
true
0
Polygon -7500403 true true 150 0 180 135 255 255 225 240 150 180 75 240 45 255 120 135

thin-arrow
true
0
Polygon -7500403 true true 150 0 0 150 120 150 120 293 180 293 180 150 300 150

truck-down
false
0
Polygon -7500403 true true 225 30 225 270 120 270 105 210 60 180 45 30 105 60 105 30
Polygon -8630108 true false 195 75 195 120 240 120 240 75
Polygon -8630108 true false 195 225 195 180 240 180 240 225

truck-left
false
0
Polygon -7500403 true true 120 135 225 135 225 210 75 210 75 165 105 165
Polygon -8630108 true false 90 210 105 225 120 210
Polygon -8630108 true false 180 210 195 225 210 210

truck-right
false
0
Polygon -7500403 true true 180 135 75 135 75 210 225 210 225 165 195 165
Polygon -8630108 true false 210 210 195 225 180 210
Polygon -8630108 true false 120 210 105 225 90 210

turtle
true
0
Polygon -7500403 true true 138 75 162 75 165 105 225 105 225 142 195 135 195 187 225 195 225 225 195 217 195 202 105 202 105 217 75 225 75 195 105 187 105 135 75 142 75 105 135 105

wolf
false
0
Rectangle -7500403 true true 15 105 105 165
Rectangle -7500403 true true 45 90 105 105
Polygon -7500403 true true 60 90 83 44 104 90
Polygon -16777216 true false 67 90 82 59 97 89
Rectangle -1 true false 48 93 59 105
Rectangle -16777216 true false 51 96 55 101
Rectangle -16777216 true false 0 121 15 135
Rectangle -16777216 true false 15 136 60 151
Polygon -1 true false 15 136 23 149 31 136
Polygon -1 true false 30 151 37 136 43 151
Rectangle -7500403 true true 105 120 263 195
Rectangle -7500403 true true 108 195 259 201
Rectangle -7500403 true true 114 201 252 210
Rectangle -7500403 true true 120 210 243 214
Rectangle -7500403 true true 115 114 255 120
Rectangle -7500403 true true 128 108 248 114
Rectangle -7500403 true true 150 105 225 108
Rectangle -7500403 true true 132 214 155 270
Rectangle -7500403 true true 110 260 132 270
Rectangle -7500403 true true 210 214 232 270
Rectangle -7500403 true true 189 260 210 270
Line -7500403 true 263 127 281 155
Line -7500403 true 281 155 281 192

wolf-left
false
3
Polygon -6459832 true true 117 97 91 74 66 74 60 85 36 85 38 92 44 97 62 97 81 117 84 134 92 147 109 152 136 144 174 144 174 103 143 103 134 97
Polygon -6459832 true true 87 80 79 55 76 79
Polygon -6459832 true true 81 75 70 58 73 82
Polygon -6459832 true true 99 131 76 152 76 163 96 182 104 182 109 173 102 167 99 173 87 159 104 140
Polygon -6459832 true true 107 138 107 186 98 190 99 196 112 196 115 190
Polygon -6459832 true true 116 140 114 189 105 137
Rectangle -6459832 true true 109 150 114 192
Rectangle -6459832 true true 111 143 116 191
Polygon -6459832 true true 168 106 184 98 205 98 218 115 218 137 186 164 196 176 195 194 178 195 178 183 188 183 169 164 173 144
Polygon -6459832 true true 207 140 200 163 206 175 207 192 193 189 192 177 198 176 185 150
Polygon -6459832 true true 214 134 203 168 192 148
Polygon -6459832 true true 204 151 203 176 193 148
Polygon -6459832 true true 207 103 221 98 236 101 243 115 243 128 256 142 239 143 233 133 225 115 214 114

wolf-right
false
3
Polygon -6459832 true true 170 127 200 93 231 93 237 103 262 103 261 113 253 119 231 119 215 143 213 160 208 173 189 187 169 190 154 190 126 180 106 171 72 171 73 126 122 126 144 123 159 123
Polygon -6459832 true true 201 99 214 69 215 99
Polygon -6459832 true true 207 98 223 71 220 101
Polygon -6459832 true true 184 172 189 234 203 238 203 246 187 247 180 239 171 180
Polygon -6459832 true true 197 174 204 220 218 224 219 234 201 232 195 225 179 179
Polygon -6459832 true true 78 167 95 187 95 208 79 220 92 234 98 235 100 249 81 246 76 241 61 212 65 195 52 170 45 150 44 128 55 121 69 121 81 135
Polygon -6459832 true true 48 143 58 141
Polygon -6459832 true true 46 136 68 137
Polygon -6459832 true true 45 129 35 142 37 159 53 192 47 210 62 238 80 237
Line -16777216 false 74 237 59 213
Line -16777216 false 59 213 59 212
Line -16777216 false 58 211 67 192
Polygon -6459832 true true 38 138 66 149
Polygon -6459832 true true 46 128 33 120 21 118 11 123 3 138 5 160 13 178 9 192 0 199 20 196 25 179 24 161 25 148 45 140
Polygon -6459832 true true 67 122 96 126 63 144

@#$#@#$#@
NetLogo 4.1.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
