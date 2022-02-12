extensions [
  gis
]

breed [corals coral]
breed [microplasticos microplastico]

globals [
  countries-dataset     ; global world from GIS world map
  corals-dataset        ; coral datos
  plastic-shore-data    ; turtles plastic from GIS data
  microplastic-as-data  ; microplasticos datos
  currents-data         ; base de datos al momento de cargar modelo GIS
  mouse-clicked?        ; para agregar microplastico con el mouse
  patches-with-no-data  ; patches sin data para la interpolacion
  corals_cant           ; contador auxiliar para corales en foreach que los carga
  microplastic_coast    ; plasticos en la costa

]

microplasticos-own [    ; agente microplastico
  t_lat                 ; latitud
  t_lon                 ; longitud
  Pieces_KM2            ; cantidad de piezas
]

corals-own [            ; agente coral
  t_lat                 ; latitud
  t_lon                 ; longitud
  microplastic-near     ; cantidad de microplasticos cercanos en piezas km
  prob                  ; probabilidad de enfermar
]

patches-own [           ; agente mundo
  area                  ; area de patch
  speed-east            ; velocidad corriente oceanica desde este
  speed-north           ; velocidad corriente oceanica desde norte
  magnitude             ; distancia recorrida por microplastico en un dia
  direction             ; direccion de movimiento de plastico (angulo de la tortuga)
  p_lat                 ; posicion lat
  p_long                ; posicion long
]


to setup
  clear-all
  gis:load-coordinate-system "../data/countries/cntry.prj"                    ; carga datos de GIS world map
  set countries-dataset gis:load-dataset "../data/countries/cntry.shp"        ; carga el data set
  gis:set-world-envelope-ds [-180 180 -60 72]                                 ; defino mundo
  set microplastic_coast 0
  set corals_cant 0
  reset-ticks         ; limpio ticks
end


to display-map                                                                ; Muestra mapa
  gis:apply-coverage countries-dataset "SQKM" area                            ; El campo SQKM tiene el area del pais
  ask patches
  [
    ifelse (area > 0 )                                                        ; Asigno azul al oceano y blanco a la tierra
    [ set pcolor brown ]
    [ set pcolor blue ]
  ]
end


to load-data                                                                  ; carga datos de corrientes oceanicas
  set currents-data gis:load-dataset "../data/dataFolder/latest_file.shp"     ; carga dataset
  add-currents-data   ; agrega corrientes en formato vectorial desde archivos
end


to add-currents-data                                                            ; Lee los datos de la superficie oceanica y extrae los vectores de caracteristicas
  foreach gis:feature-list-of currents-data                                     ; el current-data debe ser el cargado previamente en GIS
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


to fetch-currents-data [vector-feature long-coord lat-coord]                             ; para extraer datos del vector de caracteristicas desde el archivo
  let lat gis:property-value vector-feature "FIELD_1"
  let long gis:property-value vector-feature "FIELD_2"
  let VNCMS gis:property-value vector-feature "FIELD_5"
  let VECMS gis:property-value vector-feature "FIELD_4"
  assign-currents-data-to-patch lat long VNCMS VECMS long-coord lat-coord
end


to assign-currents-data-to-patch [lat long VNCMS VECMS long-coord lat-coord]       ; Asigna los datos leidos de l archivo a los patch
  if VNCMS != 0 and VECMS != 0[
    if (patch long-coord lat-coord != nobody)
    [
      ask patch long-coord lat-coord
      [
        set speed-north ( VNCMS * 86400 / 100000)                                    ; La velocidad se convierte a km/día
        set speed-east ( VECMS * 86400 / 100000)
        set p_lat lat
        set p_long long
        assign-currents
      ]
    ]
  ]
end


to assign-currents                                                                    ; funcion para calcular velocidad y direccion resultante en este y norte
  set magnitude sqrt ( speed-north * speed-north + speed-east * speed-east )          ; Asigno a los patch valores
  set direction atan speed-east speed-north
end


to interpolate-data                                         ; Asigna datos a todos loas patches sin datos (excepto sectores aislados)
  set patches-with-no-data no-data
  set-value-to-neighbour-patches
  let after-interpolation-data no-data
  if not (patches-with-no-data = after-interpolation-data)  ; recursivamente verifica y si no tiene datos los agrega
  [
    interpolate-data
  ]
end


to-report no-data                                                 ; Cuenta los parches con datos y este repor lo toma arriba patches-with-no-data
  report count patches with [ magnitude = 0 ]
end


to set-value-to-neighbour-patches                             ; Para asignar tomo valor medio de patch vecinos
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


to show-data                        ; Muestra parches con datos en pantalla en color verde
  ask patches
  [
    if magnitude = 0 and direction = 0 and not (area > 0)
    [
    set pcolor red                    ; en color rojo los mares-oceanos-patches aislados
    ]
    if magnitude != 0 and not (area > 0)
    [
    set pcolor green                  ; los mares-oceanos-patches interpolados o no
    ]
  ]

end


to clear-screen                       ; Revierte el mar a azul
  ask patches
  [
    if not (area > 0)
    [
    set pcolor blue
    ]
  ]
end

; Crea plástico para el data set seleccionado
to add-plastic-from-data
  if plastic-data  = "atlantic"
  [ add-plastic-from-data-atlantic ]
  if plastic-data = "australia"
  [ add-plastic-from-data-australia ]
end

; selector de datos plasticos atlantico
to add-plastic-from-data-atlantic                                        ; Crea tortugas con datos de plasticos
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
      create-turtles-from-data plastic-long-coord plastic-lat-coord countofplastic "none" scale   ; el color lo obteng del PIECESKM2
    ]
  ]
end

; selector de datos plasticos australia
to add-plastic-from-data-australia                                              ; Crea tortugas con datos de plasticos
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


to fetch-plastic-data-australia [plastic-long-coord plastic-lat-coord vector-feature]                 ; Function to read fields from shape file
  let cd1 gis:property-value vector-feature "CD1"
  let cd2 gis:property-value vector-feature "CD2"
  let cd3 gis:property-value vector-feature "CD3"
  let cd4 gis:property-value vector-feature "CD4"
  let scale 100
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd1 yellow scale                       ; creo tortugas con datos y el color es por el CD#
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd2 orange scale
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd3 red scale
  create-turtles-from-data plastic-long-coord plastic-lat-coord cd4 green scale
end


to create-turtles-from-data [plastic-long-coord plastic-lat-coord plastic-count plastic-color scale]      ; funcion generica para crear tortugas con datos
  let plastic-count-num 0
  ifelse is-string? plastic-count
  [
    if (plastic-count != nobody) and (plastic-count != "")
    [ set plastic-count-num read-from-string plastic-count ]                    ; si no es vacio o sin datos setea el contador
  ]
  [ set plastic-count-num  plastic-count ]                                   ; asumo que es entero seteo valor
  if (plastic-count-num != 0)
  [
    create-microplasticos int (plastic-count-num / scale)                            ; creo tortugas segun cantidad-escala
    [
      set size 2
      set xcor plastic-long-coord
      set ycor plastic-lat-coord
      if plastic-color != "none"
      [ set color plastic-color ]
    ]
  ]
  assign-lat-lon-to-turtle
end


to assign-lat-lon-to-turtle                             ; Asigna tortuga con lat y long del patch data (comunicacion patch tortuga)
  ask microplasticos                                     ; ojo que aca consulto por microplasticos y en create-turtles-from-data claramente hago create-turtles
  [
    set t_lat p_lat
    set t_lon p_long
  ]
end

; Crea microplástico para el data set seleccionado
to add-microplastic-from-data                                                ; Creates microplastic for the area selected
  if microplastic-data  = "AdventureScientits"
  [ add-microplastic-from-data-adventure-scientits ]
  if microplastic-data = "SEA"
  [ add-microplastic-from-data-SEA
    show "Este dataset puede romper netlogo"
  ]
  if microplastic-data = "GEOMAR"
  [ add-microplastic-from-data-GEOMAR ]
end

; selector de datos microplasticos
to add-microplastic-from-data-adventure-scientits                            ; Crea tortugas con datos de micro-microplasticos
; DEBE CREAR TORTUGA MICROPLASTICO Y NO PLASTICO CREO SINO NO SE PARA QUE ES LA ESCALA
  set microplastic-as-data gis:load-dataset "../data/AdventureScientist_microplastic/AdventureScientist_microplastic.shp"
  foreach gis:feature-list-of microplastic-as-data
  [
    vector-feature ->
    let microplastic-long-coord gis:property-value vector-feature "Longitude"
    let microplastic-lat-coord gis:property-value vector-feature "Latitude"
    let countofmicroplastic gis:property-value vector-feature "Total_Piec"
    let scale 1     ; 1 because is microplastic
    if check-if-inside-world-limits microplastic-long-coord microplastic-lat-coord
    [ create-turtles-from-data microplastic-long-coord microplastic-lat-coord countofmicroplastic magenta scale ]
  ]
end


to add-microplastic-from-data-SEA
  set microplastic-as-data gis:load-dataset "../data/SEA_microplastic/SEA_microplastic.shp"
  foreach gis:feature-list-of microplastic-as-data
  [
    vector-feature ->
    let microplastic-long-coord gis:property-value vector-feature "Long_deg_"
    let microplastic-lat-coord gis:property-value vector-feature "Lat_deg_"
    let countofmicroplastic gis:property-value vector-feature "Pieces_KM2"
    let scale 1     ; 1 because is microplastic
    if check-if-inside-world-limits microplastic-long-coord microplastic-lat-coord      ; verifica que este en el mapa
    [ create-turtles-from-data microplastic-long-coord microplastic-lat-coord countofmicroplastic "none" scale ]
  ]
end


to add-microplastic-from-data-GEOMAR
  set microplastic-as-data gis:load-dataset "../data/GEOMAR_microplastic/GEOMAR_microplastic.shp"
  foreach gis:feature-list-of microplastic-as-data
  [
    vector-feature ->
    let microplastic-long-coord gis:property-value vector-feature "Longitude"
    let microplastic-lat-coord gis:property-value vector-feature "Latitude"
    let countofmicroplastic gis:property-value vector-feature "MP_conc__p"
    let scale 1     ; 1 because is microplastic
    if check-if-inside-world-limits microplastic-long-coord microplastic-lat-coord        ; verifica que este en el mapa
    [ create-turtles-from-data microplastic-long-coord microplastic-lat-coord countofmicroplastic "none" scale ]
  ]
end


to-report check-if-inside-world-limits [long-coord lat-coord]      ; verifica que este en el mapa
  ifelse (long-coord > -180) and (long-coord < 180) and
         (lat-coord > -60) and (lat-coord < 72)
  [ report true ]
  [ report false ]
end

; selector de datos coral
to add-coral-from-data
  reset-timer
  set corals-dataset gis:load-dataset "../data/WCMC008_CoralReef2018_Py_v4_10percent/WCMC008_CoralReef2018_Py_v4_10percent.shp"
  ; set corals-dataset gis:load-dataset  "../data/WCMC008_CoralReefs2018/01_Data/WCMC008_CoralReef2018_Py_v4_1.shp"
  ; print gis:property-names corals-dataset
  ; output [LAYER_NAME METADATA_I ORIG_NAME FAMILY GENUS SPECIES DATA_TYPE START_DATE END_DATE DATE_TYPE VERIF NAME LOC_DEF SURVEY_MET GIS_AREA_K SHAPE_LENG SHAPE_AREA REP_AREA_K]
  ; print  gis:shape-type-of corals-dataset
  ; output POLYGON
  gis:apply-coverage corals-dataset "GIS_AREA_K" area                                   ; GIS shape file has SQKM feild which has area of the country

  ;let microplastic-long-coord gis:property-value vector-feature "Longitude"
  ;let microplastic-lat-coord gis:property-value vector-feature "Latitude"
  ;let countofmicroplastic gis:property-value vector-feature "Total_Piec"
; este codigo es para verlos como patches a los corales
;  ask patches
;  [
;    if (area > 0 )                                                               ; asigna color dle oceano rojo (no se para que)
;    [ set pcolor red ; para verlos en el mapa
;      set corals_cant (corals_cant + 1)
;    ]
;  ]
; aca termina eso de ver como patch al coral


  foreach gis:feature-list-of corals-dataset [                                    ; el coral-dataset cargado anteriormente
    this-vector-feature ->
    let curr-area gis:property-value this-vector-feature "GIS_AREA_K"              ; en esa area crearemos corales
    if (curr-area != nobody) and (curr-area != "") and (curr-area > 0)
    [
            gis:create-turtles-inside-polygon this-vector-feature corals 1
            [
              set size 3
              set t_lat p_lat
              set t_lon p_long
              set prob random-float 1
              set color green
        ;     set corals_cant (corals_cant + 1)
        ; 2.158.003 2077 ciclos son 17504
            ]

    ;set corals_cant (corals_cant + 1)
    ; 17504
    set corals_cant count corals
    ]
  ]

  type "Elapsed seconds loading corals dataset: " type timer type "\n"
end

;["LOC_DEF":"Backreef / shallow lagoon"]
;["ORIG_NAME":"Scott and Seringapatam Reefs"]
;["GIS_AREA_K":"69.7911352807"]
;["SURVEY_MET":"Not Reported"]
;["GENUS":"Not Reported"]
;["SPECIES":"Not Reported"]
;["LAYER_NAME":"CRR"]
;["END_DATE":"31/12/1998"]
;["START_DATE":"08/10/1993"]
;["DATE_TYPE":"DD"]
;["SHAPE_AREA":"0.00583694823084"]
;["REP_AREA_K":"Not Reported"]
;["FAMILY":"Not Reported"]
;["NAME":"Scott and Seringapatam Reefs"]
;["SHAPE_LENG":"6.97059831373"]
;["METADATA_I":"72.0"]
;["VERIF":"Not Reported"]
;["DATA_TYPE":"Remotely sensed; field survey"]

to assign-lat-lon-to-corals                             ; Asigna tortuga con lat y long del patch data (comunicacion patch tortuga)
  ask corals                                     ; ojo que aca consulto por microplasticos y en create-turtles-from-data claramente hago create-turtles
  [
    set t_lat p_lat
    set t_lon p_long
  ]
end


to coral-sick
  ask corals
  [
    ;neighbors-microplastic ( sum [Pieces_KM2] of microplasticos-on neighbors )                 ;hay un problema con los datos, no tiene datos la bdd
    ;set microplastic-near count microplasticos-on neighbors                                    ;cuento los microplasticos cerca y la funcion me devuelve una probabilidad de muerte por cercania
    set prob (random-prob * neighbors-microplastic (count microplasticos-on neighbors) * prob)  ; corregi funcion para calcular la probabilidad de enfermar de cada coral
    if umbral < prob
    [
      set color orange
      ;die
    ]
  ]
end


to-report random-prob
  report random-float 1 * indice
end


to-report neighbors-microplastic [var]
  report random-float 1 * var / 300
end


to add-microplastic-from-mouse                                           ; funcion para crear micro-plastico en el lugar del mouse
  if microplastic-quantity = 0                                           ; la cantidad de microplasticos debe ser mas que cero para insertarlos con el mouse OJOCONELNOMBRE
  [
    show "ATENCION, No se considera cantidad de plásticos" stop     ; error detiene funcion
  ]
  ifelse mouse-down?                                                ; si presiono click
  [
    if not mouse-clicked?                                           ; si clickie
    [
      set mouse-clicked? true                                       ; bandera
      create-microplasticos microplastic-quantity / 5 [ setxy mouse-xcor mouse-ycor set size 2 set color red ]
      create-microplasticos microplastic-quantity / 5 [ setxy mouse-xcor + 0.5 mouse-ycor + 0.5 set size 2 set color red ]
      create-microplasticos microplastic-quantity / 5 [ setxy mouse-xcor - 0.5 mouse-ycor + 0.5 set size 2 set color red ]
      create-microplasticos microplastic-quantity / 5 [ setxy mouse-xcor + 0.5 mouse-ycor - 0.5 set size 2 set color red ]
      create-microplasticos microplastic-quantity / 5 [ setxy mouse-xcor - 0.5 mouse-ycor - 0.5 set size 2 set color red ]
    ]                                                               ; transformacion para insertar una tortuga
  ]
  [
    set mouse-clicked? false                                        ; al salir para evitar la creacion continua desactivo la bandera
  ]
  assign-lat-lon-to-turtle                                          ; funcion para asignar datos del patch a la tortuga
end


to add-microplastic-rand                                            ; funcion para crear microplastico random
  create-microplasticos 10000                                       ; 10000
  [
    setxy random-xcor random-ycor
    set size 2                                                       ; tamanio 2
    set color yellow
    if area > 0                                                      ; evitar areas no significativas
      [die]
    if pcolor != blue
      [die]
  ]
  assign-lat-lon-to-turtle                                          ; funcion para asignar datos del patch a la tortuga
end


to clean-microplastics                                              ; clears all the microplastic.
  ask microplasticos [ die ]
end


to microplastic-movement                                            ; Funcion que mueve microplasticos Adaptacion ambiental
  coral-sick                                                        ; con esto verifico si enferma o no los corales
  ask microplasticos
  [
    if pcolor = blue                                                ;  para los microplasticos en el agua ejecuto la dinamica del movimiento
    [
      set heading direction                                         ; establece direccion con las corrientes

      if patch-ahead 2 != nobody                                    ; si no esta muerta
      [
        let c [pcolor] of patch-ahead 2                             ; variable local c segun ahead
        let lat2 [p_lat] of patch-ahead 2                           ; variable local lat2 segun ahead
        let lon2 [p_long] of patch-ahead 2                          ; variable local lon2 segun ahead
        ifelse scale-mag?                                           ; Si scale-mag es true uso magnitud de corriente sino muevo 1 unidad de netlogo
        [cal-distance t_lon t_lat ]
        [ fd 1 ]
      ]
    ]
    if coast-clean?
    [
      if pcolor = brown
      [
        set microplastic_coast (microplastic_coast + 1)
        die
      ]
    ]

  ]
  tick                                                              ; paso
end


to cal-distance [lon1 lat1]                                         ; funcion para actualizar datos de lat y long
  let R 6378.1                                                      ; Radio Tierra
  let b direction                                                   ; direccion
  let d magnitude                                                   ; magnitud
  let lat2 asin (
                    ( sin lat1 * cos ( (d / R) * 57.2958 )  ) +
                    ( cos lat1 * sin ( (d / R) * 57.2958 ) * cos b )
                )
  let lol atan  ( sin(b) * sin ( (d / R) * 57.2958 ) * cos(lat1)  )   (  cos ( (d / R) * 57.2958 ) - ( sin(lat1) * sin(lat2) ) )
  let lon2 0
  ifelse  lol > 180 and lol <= 360
  [
    set lon2 lon1 + lol - 360
  ][
    set lon2 lon1 +  lol
  ]                                                                 ; Calculado lat2, lon2 usando la fórmula haversine
  let target-location gis:project-lat-lon lat2 lon2                 ; Proyectar lat, lon a las coordenadas mundiales de Netlogo
  if not empty? target-location
  [
    let target-location-xcor item 0 target-location
    let target-location-ycor item 1 target-location
    setxy target-location-xcor target-location-ycor              ; Actualizando la ubicación de la tortuga
    set t_lat lat2
    set t_lon lon2
  ]
end


;to read-chunk [chunk-path]                                                        ; Función para cargar datos actuales desde un archivo (mundo)
;  let my-data gis:load-dataset chunk-path
;  foreach gis:feature-list-of my-data
;  [
;    vector-feature ->
;    let coord-tuple gis:location-of (first (first (gis:vertex-lists-of vector-feature)))
;    if not empty? coord-tuple
;    [
;      let long-coord item 0 coord-tuple
;      let lat-coord item 1 coord-tuple
;      let lat gis:property-value vector-feature "FIELD_1"
;      let long gis:property-value vector-feature "FIELD_2"
;      let VNCMS gis:property-value vector-feature "FIELD_4"
;      let VECMS gis:property-value vector-feature "FIELD_3"
;      assign-currents-data-to-patch lat long VNCMS VECMS long-coord lat-coord
;    ]
;  ]
;end
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
0
0
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
28
424
205
457
NIL
add-microplastic-rand
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
27
303
206
373
NIL
microplastic-movement
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
30
381
206
414
NIL
add-microplastic-from-mouse
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
796
451
877
496
microplasticos
count microplasticos
17
1
11

SLIDER
215
381
397
414
microplastic-quantity
microplastic-quantity
0
5000
500.0
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
213
425
395
458
clean microplastics
clean-microplastics
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
1311
450
1493
483
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
1116
451
1293
496
plastic-data
plastic-data
"atlantic" "australia"
0

SWITCH
213
302
390
335
scale-mag?
scale-mag?
1
1
-1000

BUTTON
213
181
391
226
NIL
add-microplastic-from-data
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
26
181
204
226
microplastic-data
microplastic-data
"AdventureScientits" "SEA" "GEOMAR"
0

BUTTON
27
235
206
295
NIL
add-coral-from-data
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
702
451
784
496
corales
count corals
0
1
11

MONITOR
410
451
550
496
microplasticos en costa
microplastic_coast
17
1
11

SWITCH
214
339
391
372
coast-clean?
coast-clean?
1
1
-1000

MONITOR
555
451
694
496
NIL
count turtles
17
1
11

INPUTBOX
213
234
296
294
indice
1.0
1
0
Number

INPUTBOX
303
233
391
293
umbral
0.0
1
0
Number

@#$#@#$#@
![Plastic Movement](file:../data/info/h.jpg)


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
