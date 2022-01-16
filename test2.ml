open Graphics;;
open Unix;;

open_graph " 640x480";
set_window_title "Avoid the balls"

type direction = 
    | Right
    | Left
    | Down
    | Up
;;

let directions = [Right; Left; Down; Up];;
let speed = 2;;

let lives = ref 5;;
let score = ref 0;;

(* Starting coordinates *)
let player_x = ref 0;;
let player_y = ref 0;;
let enemies = ref [|(200, 200, Right)|];;
let target_x = ref 300;;
let target_y = ref 100;;

(* Checks if two circles collided *)
let checkCollision x1 y1 r1 x2 y2 r2 = 
    (* Distance between centers should be less than two radii sum *)
    let dx = (x1 + r1) - (x2 + r2) in
    let dy = (y1 + r1) - (y2 + r2) in
    let distance = sqrt((float_of_int (dx*dx + dy*dy))) in
    distance < (float_of_int (r1+r2))

(* Checks if ball hit wall *)
let checkWallCol x y = 
    x <= 0 || x >= (size_x()) || y <= 0 || y >= (size_y())
;;

(* Generates a new enemy with random x, y, and direction *)
let randomEnemy() = 
    let posNum = Random.int 4 in
    let direction = List.nth directions posNum in
    (Random.int(size_x()), Random.int(size_y()), direction)
;;

(* Generates a new random target and increases score *)
let getNewTarget() =
    score := !score+1;
    target_x := Random.int (size_x());
    target_y := Random.int (size_y());
    enemies := (Array.append !enemies [|randomEnemy()|]);
;;

(* Gets new coordinates of ball based on direction *)
let getNewCoords x y dir = 
    match dir with
    |Right -> (x+speed, y)
    |Left -> (x-speed, y)
    |Up -> (x, y+speed)
    |Down -> (x, y-speed)
;;

(* Gets opposite direction and slightly changes x/y
    since can't spawn on top of itself *)
let oppositeDir x y dir = 
    match dir with
    |Right -> (x-10, y, Left)
    |Left -> (x+10, y, Right)
    |Up -> (x, y-1, Down)
    |Down -> (x, y+1, Up)
;;

(* Redraws field *)
let redraw() = 
    (* Erases screen *)
    set_color white;
    fill_rect 0 0 (size_x()) (size_y());
    
    (* Draws player *)
    set_color blue;
    fill_circle (!player_x) (!player_y) 15;

    (* Draw target *)
    set_color yellow;
    fill_circle (!target_x) (!target_y) 15;

    (* Checks target + player collision *)
    if (checkCollision !player_x !player_y 15 !target_x !target_y 15) then
        getNewTarget();

    (* Draws all balls *)
    set_color red;
    for i = 0 to ((Array.length !enemies)-1) do
        match (Array.get !enemies i) with
        |x, y, dir ->             
            let () = 
                (* Checks for ball + player collision *)
                if (checkCollision !player_x !player_y 15 x y 15) then
                    let () = Array.set !enemies i (randomEnemy()) in
                    lives := !lives-1
                (* Checks for ball + wall collision *)
                else if (checkWallCol x y) then
                    (* Switches direction *)
                    let oppDir = oppositeDir x y dir in
                    match oppDir with
                    |newX, newY, newDir ->
                    Array.set !enemies i (newX, newY, newDir)
                else 
                    (* Otherwise redraws in current direction *)
                    let newCoords = getNewCoords x y dir in
                    match newCoords with
                    |newX, newY -> 
                        let () = Array.set !enemies i (newX, newY, dir) in
                        fill_circle newX newY 15
            in ()
    done;;
;;

(* Game loop: 100 frames per second *)
let rec loop () =
    match mouse_pos() with
    |(x, y) -> 
        if (x < (size_x())) && (x > 0) then player_x := x;
        if (y < (size_y())) && (y > 0) then player_y := y;
    redraw();
    sleepf 0.01; (* 100 FPS *)
    (* Loops while lives > 0 *)
    if !lives > 0 then 
        loop();
;;

loop();
Printf.printf "Your score: %d\n" !score