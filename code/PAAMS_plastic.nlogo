extensions [
  gis
]


globals [
  countries-dataset   ; global world from GIS world map
  plastic-shore-data  ; turtles plastic from GIS data
  currents-data       ; no se
  mouse-clicked?      ; para agregar plastico con el mouse
  patches-with-no-data
]

turtles-own [         ; agente plastico
  t_lat               ; latitud
  t_lon               ; longitud
  p                   ; diferencia entre plastico biodegradable y no biodegradable
  useful-life         ; estatus de vida
]

patches-own [         ; agente mundo
  area                ; area de patch
  speed-east          ; velocidad corriente oceanica desde este
  speed-north         ; velocidad corriente oceanica desde norte
  magnitude           ; distancia recorrida por plastico en un dia
  direction           ; direccion de movimiento de plastico (angulo de la tortuga)
  p_lat               ; posicion lat
  p_long              ; posicion long
]


to setup
  clear-all
  gis:load-coordinate-system "../data/countries/cntry.prj"
  set countries-dataset gis:load-dataset "../data/countries/cntry.shp"
  gis:set-world-envelope-ds [-180 180 -60 72]
  reset-ticks
end



to load-data
  set currents-data gis:load-dataset "../data/dataFolder/latest_file.shp"
  add-currents-data
end



to display-map
  gis:apply-coverage countries-dataset "SQKM" area
  ask patches
  [
    ifelse (area > 0 )
    [ set pcolor brown ]
    [ set pcolor blue ]
  ]

end

to plastic-movement
  ask turtles[
    ifelse p = 2
    [if pcolor = blue
      [ set heading direction
        if patch-ahead 2 != nobody
        [ let c [pcolor] of patch-ahead 2
          let lat2 [p_lat] of patch-ahead 2
          let lon2 [p_long] of patch-ahead 2

          ; If scale-mag is true, then the magnitude of currents data is used. Else turtle is moved 1 unit.
          ifelse scale-mag?
          [cal-distance t_lon t_lat]
          [fd 1]
        ]
      ]
    ]
    [ ifelse useful-life > 0
      [ set useful-life (useful-life - 1)
        if pcolor = blue
        [ set heading direction
          if patch-ahead 2 != nobody
          [  let c [pcolor] of patch-ahead 2
            let lat2 [p_lat] of patch-ahead 2
            let lon2 [p_long] of patch-ahead 2

            ifelse scale-mag?
            [cal-distance t_lon t_lat]
            [fd 1]
          ]
        ]
      ]
      [
        die
      ]
    ]
    if (pcolor = "brown")[die]
  ]
  tick
end


to cal-distance [lon1 lat1]

  let R 6378.1
  let b direction
  let d magnitude
  let lat2 asin (
    ( sin lat1 * cos ( (d / R) * 57.2958 )  ) +
    ( cos lat1 * sin ( (d / R) * 57.2958 ) * cos b )

  )
  let lol atan  ( sin(b) * sin ( (d / R) * 57.2958 ) * cos(lat1)  )   (  cos ( (d / R) * 57.2958 ) - ( sin(lat1) * sin(lat2) ) )
  let lon2 0
  ifelse  lol > 180 and lol <= 360
  [set lon2 lon1 + lol - 360]
  [set lon2 lon1 +  lol]

  ; Calculated lat2, lon2 using haversine formula
  let target-location gis:project-lat-lon lat2 lon2
  if not empty? target-location [
    let target-location-xcor item 0 target-location
    let target-location-ycor item 1 target-location
    setxy target-location-xcor target-location-ycor
    set t_lat lat2
    set t_lon lon2
  ]

end



to add-plastic-from-mouse

  if plastic-quantity = 0
  [
    show "WARNING, No quantity of plastics are considered" stop
  ]

  ifelse mouse-down?
  [
    if not mouse-clicked? [
      set mouse-clicked? true
      crt plastic-quantity / 5 [ setxy mouse-xcor mouse-ycor set size 2 set p 0]
      crt plastic-quantity / 5 [ setxy mouse-xcor + 0.5 mouse-ycor + 0.5 set size 2 set p 0 ]
      crt plastic-quantity / 5 [ setxy mouse-xcor - 0.5 mouse-ycor + 0.5 set size 2 set p 0 ]
      crt plastic-quantity / 5 [ setxy mouse-xcor + 0.5 mouse-ycor - 0.5 set size 2 set p 0 ]
      crt plastic-quantity / 5 [ setxy mouse-xcor - 0.5 mouse-ycor - 0.5 set size 2 set p 0 ]

    ]
  ]
  [
    set mouse-clicked? false
  ]
  assign-lat-lon-to-turtle
  assign-useful-life
  assign-biodegradability-to-turtle

end



to add-plastic-rand

  create-turtles 10000
  [
 setxy random-xcor random-ycor
 set size 2
 set p 0
  if area > 0 [die]
  ]
assign-lat-lon-to-turtle
assign-useful-life
assign-biodegradability-to-turtle

end




to add-currents-data

  foreach gis:feature-list-of currents-data
  [
    vector-feature ->
    let coord-tuple gis:location-of (first (first (gis:vertex-lists-of vector-feature)))
    if not empty? coord-tuple
    [
      let long-coord item 0 coord-tuple
      let lat-coord item 1 coord-tuple
      fetch-currents-data vector-feature long-coord lat-coord
    ]
  ]

end


to fetch-currents-data [vector-feature long-coord lat-coord]

  let lat gis:property-value vector-feature "FIELD_1"
  let long gis:property-value vector-feature "FIELD_2"
  let VNCMS gis:property-value vector-feature "FIELD_5"
  let VECMS gis:property-value vector-feature "FIELD_4"
  assign-currents-data-to-patch lat long VNCMS VECMS long-coord lat-coord

end


to assign-currents-data-to-patch [lat long VNCMS VECMS long-coord lat-coord]

  if VNCMS != 0 and VECMS != 0[
    if (patch long-coord lat-coord != nobody) [
    ask patch long-coord lat-coord
    [
      set speed-north ( VNCMS * 86400 / 100000)
      set speed-east ( VECMS * 86400 / 100000)
      set p_lat lat
      set p_long long
      assign-currents
    ]
    ]
  ]

end



to assign-currents

  set magnitude sqrt ( speed-north * speed-north + speed-east * speed-east )
  set direction atan speed-east speed-north

end



to interpolate-data
  set patches-with-no-data no-data
  set-value-to-neighbour-patches
  let after-interpolation-data no-data
  if not (patches-with-no-data = after-interpolation-data)
  [
    interpolate-data
  ]
end


to set-value-to-neighbour-patches

  ask patches
  [
    if not (magnitude = 0) and not (area > 0)
    [
      ask neighbors
      [
        if magnitude = 0 and not (area > 0)
        [
          set magnitude [magnitude] of myself
          set direction [direction] of myself
          set speed-east [speed-east] of myself
          set speed-north [speed-north] of myself
          set p_lat [p_lat] of myself
          set p_long [p_long] of myself
        ]
      ]
    ]
  ]
end


to-report no-data
  report count patches with [ magnitude = 0 ]
end


to show-data
  ask patches
  [
    if magnitude = 0 and direction = 0 and not (area > 0)
    [
    set pcolor red
    ]
    if magnitude != 0 and not (area > 0)
    [
    set pcolor green
    ]
  ]
end


to clear-screen
  ask patches
  [
    if not (area > 0)
    [
    set pcolor blue
    ]
  ]
end


to clean-plastic
  ask turtles [ die ]
end


to add-plastic-from-data
  if plastic-data  = "atlantic"
  [
    add-plastic-from-data-atlantic
  ]
  if plastic-data = "australia"
  [
    add-plastic-from-data-australia
  ]
  if (plastic-data = "Marine Pollution")
  [
    add-plastic-from-data-marine-pollution
  ]
end


to add-plastic-from-data-atlantic

  set plastic-shore-data gis:load-dataset "../data/atlantic_plastic/plastic_shore.shp"
  foreach gis:feature-list-of plastic-shore-data
  [
    vector-feature ->
    let plastic-coord-tuple gis:location-of (first (first (gis:vertex-lists-of vector-feature)))
    let countofplastic gis:property-value vector-feature "PIECESKM2"
    if not empty? plastic-coord-tuple
    [
      let plastic-long-coord item 0 plastic-coord-tuple
      let plastic-lat-coord item 1 plastic-coord-tuple
      let scale 1000
      create-turtles-from-data plastic-long-coord plastic-lat-coord countofplastic "none" scale
    ]
  ]

end


to add-plastic-from-data-australia

  set plastic-shore-data gis:load-dataset "../data/australia_plastic/australia_plastic.shp"
  foreach gis:feature-list-of plastic-shore-data
  [
    vector-feature ->
    let plastic-coord-tuple gis:location-of (first (first (gis:vertex-lists-of vector-feature)))
    if not empty? plastic-coord-tuple
    [
      let plastic-long-coord item 0 plastic-coord-tuple
      let plastic-lat-coord item 1 plastic-coord-tuple
      fetch-plastic-data-australia plastic-long-coord plastic-lat-coord vector-feature
    ]
  ]

end


to-report check-if-inside-world-limits [long-coord lat-coord]
  ifelse (long-coord > -180) and (long-coord < 180) and
         (lat-coord > -60) and (lat-coord < 72)
  [ report true ]
  [ report false ]
end


to add-plastic-from-data-marine-pollution

  set plastic-shore-data gis:load-dataset "../data/PlasticMarinePollution/PlasticMarinePollution.shp"
  foreach gis:feature-list-of plastic-shore-data
  [
    vector-feature ->
    let plastic-lat-coord read-from-string gis:property-value vector-feature "Field2"
    let plastic-long-coord read-from-string gis:property-value vector-feature "Field3"
    if (check-if-inside-world-limits plastic-long-coord plastic-lat-coord)[
      fetch-plastic-data-marine-pollution plastic-long-coord plastic-lat-coord vector-feature]
  ]

end

to fetch-plastic-data-australia [plastic-long-coord plastic-lat-coord vector-feature]

  let cd1 gis:property-value vector-feature "CD1"
  let cd2 gis:property-value vector-feature "CD2"
  let cd3 gis:property-value vector-feature "CD3"
  let cd4 gis:property-value vector-feature "CD4"
  let scale 100
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd1 yellow scale
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd2 orange scale
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd3 red scale
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd4 green scale

end


to fetch-plastic-data-marine-pollution [plastic-long-coord plastic-lat-coord vector-feature]                 ; Function to read fields from shape file

  let cd1 gis:property-value vector-feature "Field4"
  let cd2 gis:property-value vector-feature "Field5"
  let cd3 gis:property-value vector-feature "Field6"
  let cd4 gis:property-value vector-feature "Field7"
  let scale 3000 ; Valor experimental para manejar el tamaño del dataset
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd1 yellow scale
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd2 orange scale
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd3 red scale
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd4 green scale

end


to create-turtles-from-data [plastic-long-coord plastic-lat-coord plastic-count plastic-color scale]
  if (plastic-count != nobody) and (plastic-count != "") and (read-from-string plastic-count != 0)
  [
    create-turtles int (read-from-string plastic-count / scale)
    [
    set size 2
    set xcor plastic-long-coord
    set ycor plastic-lat-coord
    set p 0
    if plastic-color != "none" [set color plastic-color]
    ]
  ]
  assign-lat-lon-to-turtle
  assign-useful-life
  assign-biodegradability-to-turtle
end


to read-chunk [chunk-path]   ; Function to load currents data from a shape file (world)
  let my-data gis:load-dataset chunk-path
  foreach gis:feature-list-of my-data
  [
    vector-feature ->
    let coord-tuple gis:location-of (first (first (gis:vertex-lists-of vector-feature)))
    if not empty? coord-tuple
    [
      let long-coord item 0 coord-tuple
      let lat-coord item 1 coord-tuple
      let lat gis:property-value vector-feature "FIELD_1"
      let long gis:property-value vector-feature "FIELD_2"
      let VNCMS gis:property-value vector-feature "FIELD_4"
      let VECMS gis:property-value vector-feature "FIELD_3"
      assign-currents-data-to-patch lat long VNCMS VECMS long-coord lat-coord
    ]
  ]

end


to assign-lat-lon-to-turtle ; Assigns turtles with the lat, lon with patch data turtle is on when created
  ask turtles [
    set t_lat p_lat
    set t_lon p_long
  ]
end


; Assigns turtles p=1 or p=2 depending on whether the turtle is a biodegradable plastic or not and on the amount of biodegrable plastic
to assign-biodegradability-to-turtle
  if percentage-bio-plastic = ""
 [
    show "WARNING, No quantity of biodegradable plastics are considered" stop
 ]

  let h ((count turtles * read-from-string percentage-bio-plastic) - (count turtles with [p = 1]))
  ask n-of h turtles with [p = 0] [set p 1]
  ask turtles with [p = 0] [set p 2 set useful-life 36500]
end

to assign-useful-life    ; Assigns turtles a range of useful lifetime
  (ifelse
    useful-life-bioplastic = "3-5 years"
          [ask turtles with [p = 0] [set useful-life (1095 + random 730)]]
    useful-life-bioplastic = "3-7 years"
          [ask turtles with [p = 0] [set useful-life (1095 + random 1460)]]
    [ask turtles with [p = 0] [set useful-life (1095 + random 2555)]]
   )
end
@#$#@#$#@
GRAPHICS-WINDOW
406
34
1497
442
-1
-1
3.0
1
8
1
1
1
0
1
1
1
-180
180
-60
72
1
1
1
ticks
30.0

BUTTON
28
37
204
70
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
213
37
394
70
NIL
display-map
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
29
271
206
304
NIL
add-plastic-rand
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
28
315
395
348
NIL
plastic-movement
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
31
228
208
261
NIL
add-plastic-from-mouse
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
28
362
135
407
plastic
count turtles
17
1
11

SLIDER
216
228
398
261
plastic-quantity
plastic-quantity
0
5000
1300.0
50
1
NIL
HORIZONTAL

BUTTON
213
82
395
115
NIL
interpolate-data
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
28
130
204
163
display patches data
show-data
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
213
129
395
162
clear display
clear-screen
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
214
272
396
305
clean plastic
clean-plastic
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
214
179
396
212
NIL
add-plastic-from-data
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
28
83
204
116
NIL
load-data
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
29
176
206
221
plastic-data
plastic-data
"atlantic" "australia" "Marine Pollution"
2

SWITCH
204
363
331
396
scale-mag?
scale-mag?
1
1
-1000

INPUTBOX
29
427
177
488
percentage-bio-plastic
0.7
1
0
String

CHOOSER
198
429
354
474
useful-life-bioplastic
useful-life-bioplastic
"3-5 years" "3-7 years" "3-10 years"
2

@#$#@#$#@
![Plastic Movement](file:../data/info/h.jpg)

Trabajo para la asignatura de Métodos Computacionales para la Vida Artificial. Basado en el desarrollo expuesto a continuación y modificado para ésta asignatura.

## OVERVIEW
* A lot of plastic waste is being dumped into the oceans in the recent decades.
* What happens to the non-degradable plastic in the oceans?
* Where do these plastics end up?

> **Hypothesis:** We want to observe the movement of plastics in oceans and know where the plastics ends up if dumped at a specific coastline.

## HOW IT WORKS

* Plastics get carried away by ocean surface currents and wind flows.
  * The resultant plastic displacement is directed by the calculated  magnitude and direction from ocean currents in north and east direction.
    * Resultant Velocity<sup>2</sup> = Velocity in North Direction<sup>2</sup> + Velocity in East Direction<sup>2</sup>
    * Distance Magnitude = Resultant Velocity * Time
    * Direction = tan<sup>-1</sup>( Velocity in North Direction / Velocity in East Direction)


## HOW TO USE IT

### Description of Buttons for initialization

 * Set Up => Loads the country data required to display the world map.

 * Display Map => Designates colours to patches with land in white color and ocean in blue color to display the world map.

 * Add currents data => Loads the surface currents data and initializes the patch properties with magnitude, direction, latitude, and longitude based on their north and east surface velocities.

 * Interpolate-data => Some patches may have no data of surface velocities, we interploate these empty data by considering the average data from the neighbouring patches

 * Display patches data =>  Displays all the patches with surface currents data with red colour, which helps visualize the surface currents data and the blind spots.

 * Clear display => After displaying the data with patches, this resets the display to enable further functioning. 

 * plastic-data => Here, there are two options to select (1) East of the US east coastline in the Atlantic Ocean, (2) Australia coastline. 

 * add plastic data => For the selected location specified in plastic-data, it loads the plastic data into NetLogo  

 * Add plastic from mouse => This allows the user to place plastic  anywhere in the ocean using a mouse click. The amount of plastic placed can be controlled using the plastic-quantity slider.

 * add plastic rand => This initializes the system with random plastic pollution. The amount of plastic can be controlled via the plastic-quantity slider.

 * plastic-quantity => This specifies the amount of plastic you want to add to ocean.

 * clean plastic => removes all the plastic from the simulation.


### Plastic Movement

* plastic-movement => For every tick plastics displace based on water currets data from the ocean patch of plastic.

If scale-mag? toggle is OFF, the plastic is displaced the minimum distance of 1 unit to displace to next patch considering only the direction data of ocean currents.

If scale-mag? toggle is ON, the plastic is displaced to the location calculated using haversine formula by considering both the magnitude and direction data of ocean currents.

### The flow of the initialization is mentioned in the below figure

![Flow of the initialisation](file:../data/info/flow.jpg)


### Scalings :

1 tick = 1 day
1 patch = varies based in the lat long distances (measured in km)

We get the distance plastic travels using the haversine formula.

### Description of Monitors

* Plastic => gives the total number of plastics.

## Observations

We can identify the north atlantic drift, north equitorial drifts and the other drifts of ocean currents that carries plastic debris.

The plastics form clusters and end up rotating in small circles.

After specific number of ticks we can observe where most quantity of plastics end up.


## THINGS TO TRY

Use the add-plastic-from-mouse with different amount of plastics according to the slider at different location to see how the plastic moves and observe the directions and number of ticks. This helps in understanding plastic movement over years at different start locations.

Add plastics data at US, Austraila shore to undersand what happens to plastic dumped in oceans.

## EXTENDING
 * Undestanding how natural events like cyclones and turbulence affect plastic movement in the oceans.

 * Incorporate effects of surface currents due to seasonal changes.

 * Would likewise incorporate sinking into the equation  to  understand  how  the  pollution  could  reach  and  affect  deep-sea  marine organisms and the ocean floors.


## INITIALIZATION DATA

1. Plastic dumps in the Atlantic Ocean : Lavender Law, K. and G. Proskurowski, (2012). Plastics in the North Atlantic Subtropical Gyre. IEDA. doi:10.1594/IEDA/100014

2. Plastic dumps in Indian and Pacific Ocean: Eriksen, Marcus (2014): Plastic Marine Pollution Global Dataset. figshare. Dataset. https://doi.org/10.6084/m9.figshare.1015289.v1 

3. 3.National Oceanic and Atmospheric Administration Atlantic Oceanographic and meteorological laboratory physical oceanographic division Ocean currents : global drifter program (gdp, 2011)


## Cite us

If you mention this model in a publication, we ask that you include the citation below.

Murukutla S.A., Koushik S.B., Chinthala S.P.R., Bobbillapati A., Kandaswamy S. (2021) A Simple Agent Based Modeling Tool for Plastic and Debris Tracking in Oceans. In: Dignum F., Corchado J.M., De La Prieta F. (eds) Advances in Practical Applications of Agents, Multi-Agent Systems, and Social Good. The PAAMS Collection. PAAMS 2021. Lecture Notes in Computer Science, vol 12946. Springer, Cham. https://doi.org/10.1007/978-3-030-85739-4_12
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
NetLogo 6.2.1
@#$#@#$#@
setup
display-cities
display-countries
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
