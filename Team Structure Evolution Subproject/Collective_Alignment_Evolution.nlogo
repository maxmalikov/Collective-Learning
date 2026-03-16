turtles-own[
  ;; Fundamental properties of an agent based on nowak-szamrej-latane discrete choice model with added stubborness based on fredkin-johnsen
  ;; Expanded to multiple choices based on the paper by Bancerwoski and Malarz
  ;; For now, converted to edge-based version to facilitate step counts and network evolution
  strength ;; strength of persuasiveness of the person
  stubborness ;; how convinced a person is of their opinion
  choice   ;; choice of the hint to be used during work part

  expertise-multiplier ;; unused. we can use it to bump up the random number generated during alignment of two agents;  expertise can increase the chance of influencing another
  targetdigit1 ;; number to guess for digit 1
  targetdigit2
  targetdigit3
  targetdigit4
  targetdigit5
  targetdigit6
  memdigit1 ;; memory of guesses for digit 1
  memdigit2
  memdigit3
  memdigit4
  memdigit5
  memdigit6
  guessdigit1 ;; guess for digit 1
  guessdigit2
  guessdigit3
  guessdigit4
  guessdigit5
  guessdigit6
  donedigit1 ; boolean to see if digit 1 is guessed correctly
  donedigit2
  donedigit3
  donedigit4
  donedigit5
  donedigit6
  done-count ; count how many digits are guessed
  needs-new? ; was the agent done with the puzzle and needs a new one?
  done-puzzles ; count of solved puzzles

]

globals [
  alignment-value
  alignment-time ;; time it takes to align on a decision
  alignment-time-total
  alignment-time-avg
  current-round ;; current project round, up to a maximum number-of-rounds
  total-puzzles
  total-time
  salary ;; current compensation per time unit. 1 puzzle = 1 dollar.
  palette ;; color-blind friendly palette
  alignment-list
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;     SETUP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  reset-timer
  clear-all
  clear-drawing
  reset-ticks
  ;; setup globals
  set alignment-value 0
  set alignment-time-total 0
  set alignment-time-avg 0
  set alignment-list []
  set total-time 0
  set total-puzzles 0
  set salary 0
  ;; setup field
  ask patches [ set pcolor white ]

  ;; make agents
  create-turtles group-size

  set palette (list
  (rgb 0 114 178)    ;; blue
  (rgb 230 159 0)    ;; orange
  (rgb 86 180 233)   ;; sky blue
  (rgb 0 158 115)    ;; bluish green
  (rgb 240 228 66)   ;; yellow
  (rgb 204 121 167)  ;; purple
  (rgb 213 94 0)     ;; vermillion
  (rgb 0 0 0)        ;; black
)

  reset-alignment

  ;; setup group arrangements
  (ifelse
    scenario = "consensus" [ setup-consensus ]
    scenario = "consultative" [ setup-consultative ]
    scenario = "autocratic" [ setup-autocratic ]
  )
  ;; highlight links
   ask links [ set color grey ]
  ;; This placement of alignment function is left in for testing of strategies.
  ;alignment
end

to update-attributes


  set color item choice palette

  (ifelse
    stubborness > 0.66
    [ set shape "face sad" ]
    stubborness > 0.33
    [ set shape "face neutral" ]
    [set shape "face happy" ]
  )

  set size 2 * strength + 1

end


to setup-consensus
  ;; Connect all agents
  ask turtles [ create-links-with other turtles ]
  layout-circle turtles (max-pxcor - 1)

end

to setup-consultative
  ;; Connect all agents
  ask turtle 0 [ create-links-with other turtles ]
  layout-radial turtles links (turtle 0)

end

to setup-autocratic
  ;; Connect all agents
  ask turtle 0 [ create-links-with other turtles ]
  layout-tree

end

to layout-tree
  let leader turtle 0
  let subs turtles with [who != 0]

  ask leader [
    setxy 0 (max-pycor - 10)
  ]

  let n count subs
  let width (max-pxcor - min-pxcor)
  let spacing width / (n + 1)

  let i 1
  ask subs [
    setxy (min-pxcor + i * spacing)
          (min-pycor + 10)
    set i i + 1
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;     ALIGNMENT STAGE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to reset-alignment

  set alignment-time 0


  ask turtles [
    set choice random 6
    ;set stubborness random-float 1
    set stubborness 0 ;; ignoring stubborness for now
    set strength random-float 1
    update-attributes
    set needs-new? true
    set done-puzzles 0
    set done-count 0
    set donedigit1 false
    set donedigit2 false
    set donedigit3 false
    set donedigit4 false
    set donedigit5 false
    set donedigit6 false
    set memdigit1 []
    set memdigit2 []
    set memdigit3 []
    set memdigit4 []
    set memdigit5 []
    set memdigit6 []

  ]

  if scenario = "consensus" [
    ask turtles [ set strength 0.1 ]
    ask turtle 0 [set strength 1 ]
    ask turtles [ update-attributes ]
  ]

    if scenario = "autocratic" [
      ask turtles [ set strength 0 ]
      ask turtle 0 [set strength random-float 1 ]
      ask turtles [ update-attributes ]
    ]

      if scenario = "consultative" [
      ask turtles [
      set strength 0.8
      set stubborness 0.8
    ]
      ask turtle 0 [
      set strength 0.8
      set stubborness 0.8
    ]
      ask turtles [ update-attributes ]
    ]


end

to-report consensus?
  ;; check if all turtles agree on a decision. Once they do, stop updates.
  report length remove-duplicates [choice] of turtles = 1
end

to-report entropy-alignment
  ;; reporting Shannon's entropy measure of alignment
  let total count turtles
  let entropy 0

  foreach remove-duplicates [choice] of turtles [
    c ->
    let p (count turtles with [choice = c]) / total
    set entropy entropy - (p * ln p)
  ]

  report 1 - (entropy / ln 8)
end

to alignment
  ;; record the time it will take to align
  (ifelse
    scenario = "consensus"
    [
      ;; stop alignment when everyone shares the same opinion
      while [not consensus?] [
        ;; choose between exhaustive search or random search
        if link-selection = "random" [
          ask one-of links with [color = grey] [

            bidirectional-align end1 end2
            set alignment-time alignment-time + 1

          ]
        ]
        if link-selection = "in-order" [
          ask links with [color = grey] [
            if not consensus? [
              bidirectional-align end1 end2
              set alignment-time alignment-time + 1
            ]
          ]
        ]

      ]
    ]
    scenario = "consultative"
    [
      ask one-of links with [color = grey] [
        bidirectional-align end1 end2
        set alignment-time alignment-time + 1
      ]
    ]
    scenario = "autocratic"
    [

      ask one-of links with [color = grey] [
        ;;unidirectional-align end1 end2
        bidirectional-align end1 end2

      ]
      set alignment-time 1
  ])

end

to bidirectional-align [turtle1 turtle2]
  ;; temporary placeholder for alignment. Whoever gets the higher random number will overwrite other person's choice
  let random-1 random-float 1
  let probability-a (([strength] of turtle1) - [stubborness] of turtle2) / ([strength] of turtle1 + [strength] of turtle2)
  let probability-b (([strength] of turtle2) - [stubborness] of turtle1) / ([strength] of turtle1 + [strength] of turtle2)
  ;; if strength of turtle 1 is high, and the dice rolled below it, turtle 1 will attempt to convert turtle 2
  (ifelse random-1 < probability-a
  [
      ask turtle2 [
        set choice [choice] of turtle1
        set color item choice palette
      ]
  ]
  random-1 > (1 - probability-b)
  [
      ask turtle1 [
        set choice [choice] of turtle2
        set color item choice palette
      ]
  ]
  ;; if the value falls between, then stubborness overcomes change and nothing happens.
  )

end

to unidirectional-align [turtle1 turtle2]
  ;; temporary placeholder for alignment. Leader has a 50% chance to flip the other person's choice
  ;; only 50% of the time the other agent will update their value based on leader's
  if random-float 1 > 0.75
  [
    ifelse turtle1 = turtle 0
    [ ask turtle2 [
      set choice [choice] of turtle1
      set color item choice palette
    ]]
    [ ask turtle1 [
      set choice [choice] of turtle2
      set color item choice palette
    ]]
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;     WORK STAGE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to guess-number
  if needs-new? [
    set targetdigit1 random 10
    set targetdigit2 random 10
    set targetdigit3 random 10
    set targetdigit4 random 10
    set targetdigit5 random 10
    set targetdigit6 random 10
    set needs-new? false
  ]
  ; digit 1
  if not donedigit1 [
    ; filter out made guesses
    let available (range 10)
    set available filter [ n -> not member? n memdigit1 ] available
    ; make a guess.
    if length available > 0 [
      set guessdigit1 one-of available
      ; update memory
      set memdigit1 lput guessdigit1 memdigit1
      ; check if this digit is correct
      if guessdigit1 = targetdigit1 [
        set donedigit1 true
        set done-count done-count + 1
      ]
    ]
  ]
    ; digit 2
  if not donedigit2 [
    ; filter out made guesses
    let available (range 10)
    set available filter [ n -> not member? n memdigit2 ] available
    ; make a guess.
    if length available > 0 [
      set guessdigit2 one-of available
      ; update memory
      set memdigit2 lput guessdigit2 memdigit2
      ; check if this digit is correct
      if guessdigit2 = targetdigit2 [
        set donedigit2 true
        set done-count done-count + 1
      ]
    ]
  ]
    ; digit 3
  if not donedigit3 [
    ; filter out made guesses
    let available (range 10)
    set available filter [ n -> not member? n memdigit3 ] available
    ; make a guess.
    if length available > 0 [
      set guessdigit3 one-of available
      ; update memory
      set memdigit3 lput guessdigit3 memdigit3
      ; check if this digit is correct
      if guessdigit3 = targetdigit3 [
        set donedigit3 true
        set done-count done-count + 1
      ]
    ]
  ]
    ; digit 4
  if not donedigit4 [
    ; filter out made guesses
    let available (range 10)
    set available filter [ n -> not member? n memdigit4 ] available
    ; make a guess.
    if length available > 0 [
      set guessdigit4 one-of available
      ; update memory
      set memdigit4 lput guessdigit4 memdigit4
      ; check if this digit is correct
      if guessdigit4 = targetdigit4 [
        set donedigit4 true
        set done-count done-count + 1
      ]
    ]
  ]
    ; digit 5
  if not donedigit5 [
    ; filter out made guesses
    let available (range 10)
    set available filter [ n -> not member? n memdigit5 ] available
    ; make a guess.
    if length available > 0 [
      set guessdigit5 one-of available
      ; update memory
      set memdigit5 lput guessdigit5 memdigit5
      ; check if this digit is correct
      if guessdigit5 = targetdigit5 [
        set donedigit5 true
        set done-count done-count + 1
      ]
    ]
  ]
    ; digit 6
  if not donedigit6 [
    ; filter out made guesses
    let available (range 10)
    set available filter [ n -> not member? n memdigit6 ] available
    ; make a guess.
    if length available > 0 [
      set guessdigit6 one-of available
      ; update memory
      set memdigit6 lput guessdigit6 memdigit6
      ; check if this digit is correct
      if guessdigit6 = targetdigit6 [
        set donedigit6 true
        set done-count done-count + 1
      ]
    ]
  ]
  if done-count = 6
  [
    set done-count 0
    set needs-new? true
    set donedigit1 false
    set memdigit1 []
    set memdigit2 []
    set memdigit3 []
    set memdigit4 []
    set memdigit5 []
    set memdigit6 []
    set donedigit1 false
    set donedigit2 false
    set donedigit3 false
    set donedigit4 false
    set donedigit5 false
    set donedigit6 false
    set done-puzzles done-puzzles + 1
  ]

end


to go

  let test-link one-of links with [color = grey]
  ask test-link [ set color white ]

  set alignment-time-total 0
  repeat  loop-size [
    reset-alignment
    alignment

    set alignment-time-total alignment-time-total + alignment-time
  ]
  ;set alignment-time-avg median alignment-list
  set alignment-time-avg alignment-time-total / loop-size
  set alignment-list lput alignment-time-avg alignment-list
  set alignment-value alignment-value + entropy-alignment

  if alignment-time-avg > (mean alignment-list) * 1.05 [ ask test-link [ set color grey ] ]

  ;if ticks = number-of-rounds [ stop ]

  tick

end
@#$#@#$#@
GRAPHICS-WINDOW
202
10
639
448
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
20
333
189
366
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
21
72
189
105
group-size
group-size
2
100
16.0
2
1
NIL
HORIZONTAL

CHOOSER
21
20
189
65
Scenario
Scenario
"consensus" "consultative" "autocratic"
0

BUTTON
20
374
188
407
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
769
12
871
57
Time to Align
alignment-time
3
1
11

MONITOR
657
219
858
264
Number of Links
count links with [color = grey ]
17
1
11

BUTTON
20
415
188
448
Go Once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
881
12
998
57
Shannon's Entropy
entropy-alignment
5
1
11

SLIDER
21
110
190
143
work-duration
work-duration
0
50
30.0
5
1
NIL
HORIZONTAL

SLIDER
21
148
190
181
number-of-rounds
number-of-rounds
0
2000
200.0
100
1
NIL
HORIZONTAL

MONITOR
867
220
1067
265
per loop alignment avg
alignment-time-avg
17
1
11

SLIDER
20
183
192
216
loop-size
loop-size
100
5000
5000.0
100
1
NIL
HORIZONTAL

PLOT
658
68
858
218
Number of links
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count links with [color = grey]"

PLOT
867
69
1067
219
Alignment time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot alignment-time-avg"

CHOOSER
21
220
190
265
link-selection
link-selection
"random" "in-order"
0

MONITOR
867
266
1069
311
overall alignment avg
mean alignment-list
17
1
11

@#$#@#$#@
## WHAT IS IT?

This shows how to create two different kinds of random networks.  In an Erdos-Renyi network, each possible link is given a fixed probability of being created.  In a simple random network, a fixed number of links are created between random nodes.

## THINGS TO NOTICE

SETUP-SIMPLE-RANDOM is fast as long as the number of links is small relative to the number of nodes.  If you are making networks which are nearly fully connected, then we suggest using the following code instead:

      ask turtles [ create-links-with other turtles ]
      ask n-of (count links - num-links) links [ die ]

SETUP-ERDOS-RENYI can also be written using the same idiom:

      ask turtles [ create-links-with other turtles ]
      ask links with [random-float 1.0 > probability] [ die ]

Compared to the code in the Code tab, this avoids the potentially confusing use of `self > myself`, but runs somewhat slower, especially if the linking probability is small.

## EXTENDING THE MODEL

Use the `layout-spring` command, or one of the other `layout-*` commands, to give the network a visually pleasing layout.

## RELATED MODELS

Network Example - how to dynamically create and destroy links
Preferential Attachment and Small Worlds (found under Sample Models, not under Code Examples) - how to create some other kinds of networks
Network Import Example - how to create a network based on data from a file

## CREDITS AND REFERENCES

* http://mathworld.wolfram.com/RandomGraph.html
* https://en.wikipedia.org/wiki/Random_graph

<!-- 2007 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
setup-simple-random
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
