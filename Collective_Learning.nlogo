turtles-own[
  ;; Fundamental properties of an agent based on nowak-szamrej-latane discrete choice model with added stubborness based on fredkin-johnsen
  ;; Expanded to multiple choices based on the paper by Bancerwoski and Malarz
  ;; For now, converted to edge-based version to facilitate step counts and network evolution
  strength ;; strength of persuasiveness of the person
  expertise-list ;; list of certainties for each of the choices. When an agent switches choice, their stubborness value for that choice is pulled from this list
  rewards-count ;; how many rounds of rewards there were for each choice
  rewards-avg ;; running rewards average list for each choice
  stubborness ;; how certain a person is of their opinion. pulled from expertise-list
  choice   ;; current top choice of the hint to be used during work part 0 = odd/even, 1 = prime/not prime, 2 = number of letters in digit's name
           ;; 3 = number of letter "e" in the name, 4 = lesser/greater hint, 5 = distance to the target



  ;; reworking to use a list - support as many or as little digits as needed.
  targets      ;; list of target digits
  guesses      ;; list of guess digits (or -1 if not guessed yet)
  memories     ;; list of memory for each guess
  done-flags   ;; list of tracker for each digit

  ;; these variables deal with actual guessing part
  done-count ;; count how many digits are guessed
  needs-new? ;; was the agent done with the puzzle and needs a new one?
  done-puzzles ;; count of solved puzzles
  reward-plot ;; stores the number of puzzles solved for plotting.

]

globals [

  alignment-time ;; time it takes to align on a decision
  ;;alignment-threshold ;; the level of punishment on agents that do not align. It is now set through the interface
  current-round ;; current project round, up to a maximum number-of-rounds
  total-puzzles ;; global count of puzzles
  total-time ;; total time including alignment and work
  salary ;; current compensation per time unit.
  palette ;; color-blind friendly palette
  explore-param ;; exploration parameter in upper confidence bound calculations
  num-feedback-options ;; how many feedback options there are
  group-choice
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;     SETUP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  ;; reset values for the simulation
  reset-timer
  clear-all
  clear-drawing
  reset-ticks

  ;; setup globals
  set alignment-time 0
  ;; set alignment-threshold 3 ; this is set through the interface now
  set total-time 0
  set total-puzzles 0
  set salary 0
  set explore-param 3 ;; can be changed to allow for more exploration of values
  set num-feedback-options 6

  ;; setup field
  ask patches [ set pcolor white ]

  ;; make agents
  create-turtles group-size

  ;; define palette for the choices
  set palette (list
    (rgb 0 114 178)    ;; blue
    (rgb 230 159 0)    ;; orange
    (rgb 86 180 233)   ;; sky blue
    (rgb 0 158 115)    ;; bluish green
    (rgb 240 228 66)   ;; yellow
    (rgb 150 150 150)  ;; grey
    (rgb 204 121 167)  ;; purple
    (rgb 213 94 0)     ;; vermillion
)

  ;; setup agent's variables
  ask turtles [
    ;; reset rewards memory; only done at the start of the simulation
    set rewards-count n-values num-feedback-options [0]
    set rewards-avg n-values num-feedback-options [0]
    set reward-plot 0

    ;; personal preferences
    set strength random-float 1 ;; this value does not change
    set expertise-list get-stubbornness-vector
    set choice weighted-choice expertise-list
    set stubborness item choice expertise-list
    ;; for testing
    ;;set stubborness random-float 1
    update-attributes

  ]
  reset-alignment ;; this function resets most of agent's variables. It's used to setup round-specific variables


  ;; setup group arrangements
  (ifelse
    scenario = "consensus" [ setup-consensus ]
    scenario = "consultative" [ setup-consultative ]
    scenario = "autocratic" [
      ask turtles [ set strength 0 ]
      ask turtle 0 [set strength random-float 1 ]
      ask turtles [ update-attributes ]
      setup-autocratic
    ]
  )
  ;; highlight links
   ask links [ set color grey ]

end

to update-attributes
 ;; update colors, size, shape of agents
  set color item choice palette ; set color from the palette

  ; change the face shape based on certainty
  (ifelse
    stubborness > 0.66
    [ set shape "face sad" ]
    stubborness > 0.33
    [ set shape "face neutral" ]
    [set shape "face happy" ]
  )

  ; change size based on the strength of influence
  set size 2 * strength + 1

end


to setup-consensus
  ;; Connect all agents in a circular network
  ask turtles [ create-links-with other turtles ]
  layout-circle turtles (max-pxcor - 1)

end

to setup-consultative
  ;; Connect all agents in a wheel network
  ask turtle 0 [ create-links-with other turtles ]
  layout-radial turtles links (turtle 0)

end

to setup-autocratic
  ;; Connect all agents in a tree layout
  ask turtle 0 [ create-links-with other turtles ]
  layout-tree

end

; use positioning to create a top-down structure
to layout-tree
  let leader turtle 0
  let subs turtles with [who != 0]

  ; set leader at the top
  ask leader [
    setxy 0 (max-pycor - 10)
  ]

  ; decide the spacing for the agents.
  let n count subs
  let width (max-pxcor - min-pxcor)
  let spacing width / (n + 1)

  ; arrange subordinates in a line below the leader
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

; function used to reset variables specific to a round.
to reset-alignment

  ; reset global variable that tracks time of alignments
  set alignment-time 0

;; round specific attributes for individual agents
  ask turtles [

    set done-puzzles 0 ; reset the amount of work done
    ;; tracking attributes
    set needs-new? true ; make sure that a new puzzle is generated at the start
    set done-count 0 ;; done digits counter
    ;; guess-related attributes
    set targets n-values 6 [ 0 ]
    set guesses n-values 6 [ 0 ]
    set memories n-values 6 [ [] ]
    set done-flags n-values 6 [ false ]
    update-attributes ; update color, shape, size
  ]


end

to-report consensus?
  ;; check if all turtles agree on a decision. Once they do, we can stop updates in the main function.
  report length remove-duplicates [choice] of turtles = 1
end

to-report entropy-alignment
  ;; reporting Shannon's entropy measure of alignment
  let total count turtles
  let entropy 0

  ;; based
  foreach remove-duplicates [choice] of turtles [
    c ->
    let p (count turtles with [choice = c]) / total
    set entropy entropy - (p * ln p)
  ]

  report 1 - (entropy / ln 6) ; 6 = number of choices. Could be recoded to be an input variable.
end

to alignment
  ;; run alignment step and record the time it will take to align
  (ifelse
    scenario = "consensus"
    [

      ;; currently runs ONCE for each turtle, then stops; unless alignment is reached earlier.
      ask turtles [
        if not consensus? [
          ;; older pairwise algorithm - left in for now.
          ;; bidirectional-align end1 end2
          ;; set alignment-time alignment-time + 1
          update-turtle ; this function runs the actual opinion dynamics alignment
          set alignment-time alignment-time + ( 2 * count links / count turtles )
        ]

      ]

      ;; stop alignment when everyone shares the same opinion
    ]
    scenario = "consultative"
    [
      ;; Currently run ONCE for each turtle; however we should convert this to:
      ; run ONCE, then run dissemination of choice (like the autocratic option below).
      ask turtles [
        ;;bidirectional-align end1 end2
        ;;set alignment-time alignment-time + 1
        update-turtle

      ]
      ;; Depending on how the alignment is done above, the count of links (equivalent to alignment time) may change.
      set alignment-time 2 * count links
    ]
    scenario = "autocratic"
    [
      ;; Run ONCe for each turtle. Should be unidirectional (currently done by setting subordinate strength to 0)
      ask turtles [
        ;;unidirectional-align end1 end2
        ;;bidirectional-align end1 end2
        update-turtle

      ]
      set alignment-time count links
  ])

end

to update-turtle

  ;; we need to aggregate the impacts of all the neighbors that hold each of the choices.
  let impact1 0
  let impact2 0
  let impact3 0
  let impact4 0
  let impact5 0
  let impact6 0
; add the "certainty" amount to the choice that is shared by the agent
    (ifelse
      choice = 0 [ set impact1 impact1 + stubborness]
      choice = 1 [ set impact2 impact2 + stubborness]
      choice = 2 [ set impact3 impact3 + stubborness]
      choice = 3 [ set impact4 impact4 + stubborness]
      choice = 4 [ set impact5 impact5 + stubborness]
      choice = 5 [ set impact6 impact6 + stubborness]
    )
  ; for all choices, reduce the impact of other neighbors by the complement of agent's certainty in their current choice.
  ; this currently includes even the impact of other agents that share my choice. But that can change.
  ask link-neighbors
  [
    (ifelse
      choice = 0 [ set impact1 impact1 + (strength) * (1 - [stubborness] of myself) ]
      choice = 1 [ set impact2 impact2 + (strength) * (1 - [stubborness] of myself) ]
      choice = 2 [ set impact3 impact3 + (strength) * (1 - [stubborness] of myself) ]
      choice = 3 [ set impact4 impact4 + (strength) * (1 - [stubborness] of myself) ]
      choice = 4 [ set impact5 impact5 + (strength) * (1 - [stubborness] of myself) ]
      choice = 5 [ set impact6 impact6 + (strength) * (1 - [stubborness] of myself) ]
    )
  ]
;; make a list of all the impact values and find the MAX value. Paper also suggests using a softmax or another approach.
  let impacts (list impact1 impact2 impact3 impact4 impact5 impact6)
  let max-impact max impacts
  let max-index position max-impact impacts
  ;; max index is 0-5, and we can simply set the choice to the position of the largest impact.
  set choice max-index
  set stubborness item choice expertise-list
  update-attributes ; update color, shape, size.

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;     WORK STAGE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to guess-number
  ;; if a new puzzle is needed, reset trackers and generate a target number
  if needs-new? [
    set targets n-values 6 [ random 10 ]
    set guesses n-values 6 [ 0 ]
    set memories n-values 6 [ [] ]
    set done-flags n-values 6 [ false ]
    set needs-new? false
  ]

  ;; loop through each digit
  let i 0
  while [i < 6] ;; should probably be set through an interface.
  [
    ;; check if the digit is guessed correctly already. Do nothing if it was
    if not item i done-flags [
      ;; If it still needs to be guessed, we will generate a range of possible choices, then
      ;; remove everything that we tried and things that were added to memory because they were eliminated by feedback.
      let target item i targets ; retrieve the target number
      let mem item i memories ; retrieve the correct set of ineligible digits
      let available (range 10)

      ;; see if the agent is aligned
      if choice = group-choice or i < alignment-threshold ;; if not aligned, only give the first X hints
      [
        ;; Rather than running a filter for each possibility, we add unavailable digits to memory, and then just run the filter once.
        ;; 0 -> Odd or even
        if choice = 0 [
          ifelse target mod 2 = 0
          [ set mem sentence mem [1 3 5 7 9] ]
          [ set mem sentence mem [0 2 4 6 8] ]
        ]
        ;; 1 -> Prime or not
        if choice = 1 [
          ifelse member? target [1 2 3 5 7]
          [ set mem sentence mem [0 4 6 8 9] ]
          [ set mem sentence mem [1 2 3 5 7] ]
        ]
        ;; 2 -> Number of Letters in the digit
        if choice = 2
        [
          ;; filter out other guesses based on the number of letters
          (ifelse
            ;; three letters
            member? target [1 2 6]
            [ set mem sentence [3 4 5 7 8 9 0] mem ]
            ;; four letters
            member? target [4 5 9 0]
            [ set mem sentence [1 2 3 6 7 8] mem ]
            ;; five letters
            member? target [3 7 8]
            [ set mem sentence [1 2 4 5 6 9 0] mem ]
          )
        ]
        if choice = 3
        [
          (ifelse
            ;; 0 "e"s
            member? target [2 4 6]
            [ set mem sentence [1 3 5 7 8 9 0] mem ]
            ;; 1 "e"
            member? target [1 5 8 9 0]
            [ set mem sentence [2 3 4 6 7] mem ]
            ;; 2 "e"s
            member? target [3 7]
            [ set mem sentence [1 2 4 5 6 8 9 0] mem ]
          )
        ]
      ]
      ;; filter out unavailable digits stored in memory from the list of available guesses
      set available filter [ n -> not member? n mem ] available

      ;; guess one of the numbers remaining in the available list
      if length available > 0 [
        let guess one-of available
        set guesses replace-item i guesses guess
        set mem lput guess mem ; store the guess in memory

        ;; see if the agent is aligned - reduce the number of hints available
        if choice = group-choice or i < alignment-threshold ;; if not aligned, only give the first X hints
        [
          ;; Hints as response to guesses
          ;; Smaller or larger
          if choice = 4
          [
            if target > guess [
              foreach available [ x ->
                if x < guess [ set mem lput x mem ]
              ]
            ]
            if target < guess [
              foreach available [ x ->
                if x > guess [ set mem lput x mem ]
              ]
            ]
          ]
          ;; Distance to the guess <- the most optimal feedback desired!
          if choice = 5
          [
            let guess-distance abs (target - guess)
            foreach available [ x ->
              if abs (x - guess) != guess-distance [
                set mem lput x mem
              ]
            ]
          ]
        ]
        ;; check the actual guess
        if guess = target [
          set done-flags replace-item i done-flags true
          set done-count done-count + 1
        ]
        ;; store updated memory back into list
        set memories replace-item i memories mem
      ]

    ]
    ;; iterate the digit tracket
          set i i + 1
  ]
  ;; See if we guessed the whole number and need to reset the done flag
  if done-count = 6
  [
    set done-count 0
    set needs-new? true
    set done-puzzles done-puzzles + 1
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;     LEARN STAGE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; function to generate a softmax list of probabilities for certainty for each choice.
to-report softmax [values-list]
  let max-value max values-list
  let shifted map [v -> v - max-value] values-list
  let exps map [v -> exp v] shifted
  let sum-exps sum exps
  report map [v -> v / sum-exps] exps
end

to-report get-ucb-value [feedback-option]
  ;; get count for this option
  let n item feedback-option rewards-count

  ;; if never chosen, treat count as 1
  if n = 0 [
    ;set n work-duration / 5 ;; this was used to adjust the UCB value based on the expected number of puzzles done
    set n 1
  ]

  ;; total number of selections so far
  let t (sum rewards-count) + 1

  ;; return UCB bonus
  report explore-param * sqrt (ln t / n)
end

to-report get-stubbornness-vector
  ;; create a list of length num-feedback-options, initialized with 0
  let feedback-option-values n-values num-feedback-options [0]


  ;; fill in each value: rewards average [i] + UCB bonus
  let i 0
  while [i < num-feedback-options]
  [
    let reward-instance item i rewards-avg
    ;; Updated - helped a bit but not much.
    if reward-instance = 0 [ set reward-instance work-duration / 6 ] ;; expected value if it is currently set to 0
    set feedback-option-values replace-item i feedback-option-values (reward-instance + get-ucb-value i)
    set i i + 1
  ]
  report softmax feedback-option-values

end

to update-reward [ reward ]

  ;; index of previously chosen option
  let i choice

  ;; increment count
  let current-count item i rewards-count
  set rewards-count replace-item i rewards-count (current-count + 1)

  ;; updated count
  let n current-count + 1

  ;; get current value
  let current-value item i rewards-avg

  ;; running average update
  set rewards-avg replace-item i rewards-avg (current-value + (reward - current-value) / n)

end

;; We needed to implement a special weighted-choice function, as it is not available in NetLogo.
to-report weighted-choice [prob-list]

  ;; Generate a list of cumulative values, and use random number generator to pick one of them
  let r random-float 1
  let cumulative 0
  let i 0

  while [i < length prob-list]
  [
    set cumulative cumulative + item i prob-list
    if r <= cumulative [
      report i
    ]
    set i i + 1
  ]

  ;; fallback (floating point safety)
  report (length prob-list - 1)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;     OVERALL FLOW STAGE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; the main function of the model; runs once for each step
to go

  ;; we run one round of alignment...
  ifelse ticks mod (work-duration + 1) = 0
  [
    ;; aggregate values of completed work and time it took
    set total-puzzles sum [done-puzzles] of turtles
    set total-time alignment-time + work-duration
    set salary total-puzzles / (total-time * count turtles)
    ;; learn from the previous round
    if ticks != 0
    [
      ask turtles [
        ;; use current choice to update the count of scores and value of scores
        set reward-plot done-puzzles
        update-reward done-puzzles
        set expertise-list get-stubbornness-vector
        set choice weighted-choice expertise-list
        set stubborness item choice expertise-list
        update-attributes
      ]
      ;; reset round-specific variables
      reset-alignment
    ]
    ;; run alignment!
    alignment
      ;; Important! setup group choice value. This could be altered to other options.
    (ifelse
      scenario = "consensus" [ set group-choice one-of modes [choice] of turtles ]
      scenario = "consultative" [ set group-choice [choice] of turtle 0  ]
      scenario = "autocratic" [ set group-choice [choice] of turtle 0 ]
    )
  ]
  ;; ...and then we run #work-duration rounds of actual work.
  [
    ask turtles [ guess-number ]
  ]

  ;; stop when the experiment duration ends
  if ticks = 1 + (work-duration + 1) * number-of-rounds [ stop ]

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
20.0
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
2

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
12
758
57
Number of Links
count links
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

MONITOR
657
270
714
327
 
[item 0 targets] of turtle 0
1
1
14

TEXTBOX
658
242
808
260
Agent 0 Target Number
14
0.0
1

TEXTBOX
658
365
808
383
Agent 0 Guess
14
0.0
1

MONITOR
714
270
771
327
 
[item 1 targets] of turtle 0
17
1
14

MONITOR
771
270
828
327
 
[item 2 targets] of turtle 0
17
1
14

MONITOR
828
270
885
327
 
[item 3 targets] of turtle 0
17
1
14

MONITOR
885
270
942
327
 
[item 4 targets] of turtle 0
17
1
14

MONITOR
942
270
999
327
 
[item 5 targets] of turtle 0
17
1
14

MONITOR
658
391
715
448
 
[item 0 guesses] of turtle 0
17
1
14

MONITOR
715
391
772
448
 
[item 1 guesses] of turtle 0
17
1
14

MONITOR
772
391
829
448
 
[item 2 guesses] of turtle 0
17
1
14

MONITOR
829
391
886
448
 
[item 3 guesses] of turtle 0
17
1
14

MONITOR
886
391
943
448
 
[item 4 guesses] of turtle 0
17
1
14

MONITOR
943
391
1000
448
 
[item 5 guesses] of turtle 0
17
1
14

SLIDER
20
136
189
169
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
19
205
188
238
number-of-rounds
number-of-rounds
0
200
200.0
10
1
NIL
HORIZONTAL

PLOT
657
81
998
231
Average puzzles per step per turtle
NIL
NIL
0.0
10.0
0.0
0.11
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot salary"

TEXTBOX
453
534
603
552
  █
11
45.0
1

TEXTBOX
222
472
372
490
Legend - Feedback Type
11
0.0
1

TEXTBOX
484
534
634
552
4. Plus / Minus
11
0.0
1

TEXTBOX
229
535
379
553
  █
11
26.0
1

TEXTBOX
454
563
604
581
  █
11
4.0
1

TEXTBOX
229
566
379
584
  █
11
96.0
1

TEXTBOX
230
505
380
523
  █
11
94.0
1

TEXTBOX
454
503
604
521
  █
11
74.0
1

TEXTBOX
261
536
411
554
1. Prime / Not Prime
11
0.0
1

TEXTBOX
266
506
416
524
0. Odd / Even
11
0.0
1

TEXTBOX
264
566
414
584
2. Count Letters in Digit Name
11
0.0
1

TEXTBOX
488
503
638
521
3. Letters \"e\" in Digit Name
11
0.0
1

TEXTBOX
486
563
636
581
5. Distance to Target
11
0.0
1

MONITOR
1511
69
1712
114
average rewards of turtle 0
map [x -> precision x 2] [rewards-avg] of turtle 0
17
1
11

MONITOR
1510
121
1711
166
NIL
[rewards-count] of turtle 0
17
1
11

MONITOR
1509
174
1711
219
expertise list of turtle 0
map [x -> precision x 2] [expertise-list] of turtle 0
2
1
11

MONITOR
1509
226
1711
271
NIL
[choice] of turtle 0
17
1
11

MONITOR
1510
280
1711
325
puzzles per round of turtle 0
[reward-plot] of turtle 0
17
1
11

MONITOR
1510
335
1711
380
NIL
[stubborness] of turtle 0
17
1
11

MONITOR
1508
389
1710
434
NIL
[strength] of turtle 0
17
1
11

TEXTBOX
1511
24
1661
42
Monitoring Turtle 0 for testing
11
0.0
1

PLOT
1022
12
1487
158
Turtle choices over time
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
"0" 1.0 0 -14985354 true "" "plot count turtles with [choice = 0]"
"1" 1.0 0 -817084 true "" "plot count turtles with [choice = 1]"
"2" 1.0 0 -8275240 true "" "plot count turtles with [choice = 2]"
"3" 1.0 0 -15302303 true "" "plot count turtles with [choice = 3]"
"4" 1.0 0 -1184463 true "" "plot count turtles with [choice = 4]"
"5" 1.0 0 -9276814 true "" "plot count turtles with [choice = 5]"

PLOT
1022
165
1486
306
Expertise weights for Turtle 0
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -14454117 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[ plot item 0 [expertise-list] of turtle 0 ]"
"pen-1" 1.0 0 -817084 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[plot item 1 [expertise-list] of turtle 0]"
"pen-2" 1.0 0 -11033397 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[plot item 2 [expertise-list] of turtle 0]"
"pen-3" 1.0 0 -15302303 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[plot item 3 [expertise-list] of turtle 0]"
"pen-4" 1.0 0 -1184463 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[plot item 4 [expertise-list] of turtle 0]"
"pen-5" 1.0 0 -9276814 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[plot item 5 [expertise-list] of turtle 0]"

SLIDER
19
280
191
313
alignment-threshold
alignment-threshold
0
6
3.0
1
1
NIL
HORIZONTAL

TEXTBOX
24
249
186
277
# of digits for which hints are given when not aligned
11
0.0
1

TEXTBOX
28
188
178
206
Total number of work rounds
11
0.0
1

TEXTBOX
26
120
176
148
Number of steps per round
11
0.0
1

PLOT
1022
316
1489
450
Average expertise weights
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -14454117 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[ plot mean map [ t -> item 0 [expertise-list] of t ] sort turtles ]"
"pen-1" 1.0 0 -817084 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[ plot mean map [ t -> item 1 [expertise-list] of t ] sort turtles ]"
"pen-2" 1.0 0 -11033397 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[ plot mean map [ t -> item 2 [expertise-list] of t ] sort turtles ]"
"pen-3" 1.0 0 -15302303 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[ plot mean map [ t -> item 3 [expertise-list] of t ] sort turtles ]"
"pen-4" 1.0 0 -1184463 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[ plot mean map [ t -> item 4 [expertise-list] of t ] sort turtles ]"
"pen-5" 1.0 0 -9276814 true "" "ifelse ticks = 0 \n[ plot 0 ]\n[ plot mean map [ t -> item 5 [expertise-list] of t ] sort turtles ]"

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
