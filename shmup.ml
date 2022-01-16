open Graphics;;
open Unix;;
#load "graphics.cma";;
#load "unix.cma";;
 
let pi = 4. *. atan 1.(*Pi*);;

(******************************************************************************)


(*Paramatres temporels*)

(*Le temps propre de l'observateur.*)
let observer_proper_time = ref 1.;;(*En ratio du temps absolue de l'univers*)
(*Le game_speed_target est la vitesse a laquelle on veut que le jeu tourne en temps normal*)
let pause = ref false;;
let restart = ref false;;
let quit = ref false;;
let game_speed_target_pause = 0. ;; (*Vitesse du jeu en pause*)
let game_speed_target_death = 0.8 ;;(*Vitesse du jeu apres mort*)
let game_speed_target_boucle = 1.;; (*Vitesse du jeu par defaut*)
let game_speed_target = ref 1.;;
(*Le game_speed est la vitesse reelle a laquelle le jeu tourne a l'heure actuelle.*)
(*Cela permet notamment de faire des effets de ralenti ou d'accalere*)
let game_speed = ref 1.;;
(*Le half_speed_change determine a quelle vitesse le game speed se rapproche de game_speed_target (En demi-vie) *)
let half_speed_change = 0.1;;

(*Ratios de changement de vitesse en fonction des �v�nements*)
let ratio_time_explosion = 0.99;;
let ratio_time_destr_asteroid = 0.95;;
let ratio_time_tp = 0.;;
let ratio_time_death = 0.5;;

(*Timer pour la mort*)
let time_of_death = ref 0.;;
let time_stay_dead_min = 1.;;
let time_stay_dead_max = 5.;;

(*La limitation de framerate est activable,
mais il semblerait que le gettimeofday et l'attente de Unix.select
ne soient pas assez pr�cis pour que chaque frame dure juste le temps qu'il faut.
Mon conseil est de ne pas l'activer.*)
let locked_framerate = ref false;;
(*Le framerate demand� dans l'�nonc� est de 20.
Un framerate plus �lev� offre une meilleure exp�rience de jeu :
Des contr�les plus r�actifs, un meilleur confort visuel, et une physique plus pr�cise.
Bien s�r, il est possible de le changer ci-dessous
(n'a d'effet qu'avec le locked_framerate activ�)*)
let framerate_limit = 300.;;
(*Le framerate de rendu permet de d�terminer la longueur du motion blur.
R�glez au framerate r�el de votre �cran,
et shutter_speed contr�le la longueur du flou comme une cam�ra r�elle*)
let framerate_render = 60.;;

(*On stocke le moment auquel la derni�re frame a �t� calcul�e
pour synchroniser correctement le moment de calcul de la frame suivante*)
let time_last_frame = ref 0.;;
let time_current_frame = ref 0.;;

(*Pour le calcul des fps, on stocke le dernier moment auquel on comptait les images, et on actualise r�guli�rement.*)
let time_last_count = ref 0.;;
let time_current_count = ref 10.;;
let last_count = ref 0;;
let current_count = ref 0;;

(*Dimensions fenetre graphique.*)
let width = 1360;;
let height = 760;;
let game_surface = 30.;; (*D�termine la taille du terrain de jeu.*)
let max_dist = 20000.;;
(*Dimensions de l'espace physique dans lequel les objets �voluent.
On s'assure que la surface de jeu soit la m�me quelle que soit la r�solution.
On conserve au passage le ratio de la r�solution pour les dimensions de jeu
On a une surface de jeu de 1 000 000 par d�faut*)
let projectile_number_default = 1;;

(*L'antialiasing de jitter fait �trembler� l'espace de rendu.
C'est une forme de dithering spatial
afin de compenser la perte de pr�cision due � la rast�risation
lors du placement des objets et du trac� des contours.*)
let dither_aa = true;;
(*La puissance du jitter d�termine � quel point le rendu peut se d�caler.*)
(*D�terminer � 1 ou moins pour �viter un effet de flou et de fatigue visuelle*)
let dither_power = 0.5 ;;(*En ratio de la taille d'un pixel*)
let dither_power_radius = 0.5;;
(*Le jitter double courant permet de faire le m�me jitter sur les positions d'objets.
Cela permet de s'assurer une consistance spatiale dans tout le rendu.*)
let current_jitter_double = ref (0.,0.);;

let filter_half_life = 1.;;
let filter_saturation = 0.5;;

let space_half_life = 1.;;

let ratio_rendu = ref (sqrt ((float_of_int width) *. (float_of_int height) /. (game_surface *. 1000000.)));;
(*Tailles �physiques� du terrain*)
let phys_width = ref (float_of_int width /. !ratio_rendu);;
let phys_height = ref (float_of_int height /. !ratio_rendu);;

let width_collision_table = 15;;
let height_collision_table = 9;;


(******************************************************************************)
(*Param�tres graphiques avanc�s*)

(*Coleurs random par etape*)
let rand_min_lum = 0.5;;
let rand_max_lum = 1.5;;
let space_saturation = 2.;;
let star_saturation = 8.;;
let dyn_color = ref true;;

(*Couleurs des boutons*)
let truecolor = rgb 0 128 0;;
let falsecolor = rgb 128 0 0;;
let slidercolor = rgb 128 128 128;;
let buttonframe = rgb 64 64 64;;
let buttonframewidth = int_of_float (10. *. !ratio_rendu);;

(*Param�tres de flou de mouvement*)
(*Impl�ment� correctement pour les bullets et �toiles,
dessine des train�es derri�re les autres types d'objets,
mais de mani�re erratique, donc d�sactiv� par d�faut*)
let motion_blur = ref false;;
let shutter_speed = 1.;;

(******************************************************************************)
(*Param�tres de jeu*)

(*Les contr�les directs ne contr�lent pas la vitesse et le moment mais directement la position et la rotation.
Les valeurs par d�faut sont celles demand�es dans le tp*)
let ship_direct_pos = ref false;;
let ship_direct_rotat = ref false;;
let ship_impulse_pos = ref true;;
let ship_impulse_rotat = ref true;;

(*Ratio pour conversion des d�gats physiques depuis le changement de v�locit� au carr�*)
let ratio_phys_deg = ref 0.001;;
let advanced_hitbox = ref true;;

(*Let objets physiques en contact se repoussent un peu plus que normal pour �viter d'�tre imbriqu�s*)
let min_repulsion = 100.;;
let min_bounce = 1000.;;

(*Param�tres des ast�ro�des*)
let asteroid_max_spawn_radius = 650. ;;(*Taille max d'ast�ro�de au spawn.*)
let asteroid_min_spawn_radius = 350. ;;(*Taille min de spawn*)
let asteroid_max_moment = 1.;; (*Rotation max d'un ast�ro�de au spawn (dans un sens al�atoire)*)
let asteroid_max_velocity = 2000.;; (*Velocit� max au spawn*)
let asteroid_min_velocity = 1500. ;;(*Velocit� min au spawn*)
let asteroid_stage_velocity = 500. ;;(*Permet aux ast�ro�des de stages plus avanc�s d'aller plus vite*)
let asteroid_density = 1.;; (*Sert � d�terminer la masse d'un ast�ro�de en se basant sur sa surface*)
let asteroid_min_health = 50.;; (*�vite les ast�ro�des trop fragiles � cause d'une masse trop faible. S'additionne au calcul.*)
let asteroid_mass_health = 0.01;;(*Sert � d�terminer la vie d'un ast�ro�de bas� sur sa masse*)
(*Dam : dommmages. phys : dommages physiques. Ratio : Multiplicateur du d�gat. res : r�sistance aux d�gats (soustraction)*)
let asteroid_dam_ratio = 1. ;;(*La sensibilit� aux d�gats d'explosions*)
let asteroid_dam_res = 0.;; (*La r�sistance aux d�gats d'explosions*)
let asteroid_phys_ratio = 1.;; (*Sensibilit� aux chocs physiques*)
let asteroid_phys_res = 100.;; (*R�sistance aux chocs physiques*)
(*Param�tres pour les couleurs d'ast�ro�des � la naissance*)
let asteroid_min_lum = 40.;;
let asteroid_max_lum = 120.;;
let asteroid_min_satur = 0.4;;
let asteroid_max_satur = 0.5;;
(*Param�tres de la hitbox et des visuels polygonaux*)
let asteroid_polygon_min_sides = 7;;(*Nombre minimum de c�t�s qu'un ast�ro�de peut avoir*)
let asteroid_polygon_size_ratio = 0.02;; (*Permet de d�terminer le nombre de c�t�s qu'un ast�ro�de aura pour sa hitbox et son rendu. Permet de rendre les gros projectiles plus d�taill�s, et les petits moins consommateurs en perfs.*)
let asteroid_polygon_min = 1.;; (*En ratio du rayon*)
let asteroid_polygon_max = 1.3 ;;(*En ratio du rayon*)
(*Contr�le du nombre d'ast�ro�de apparaissant � chaque vague*)
let asteroid_min_nb = 2;;
let asteroid_stage_nb = 1;;
let asteroid_min_size = 100.;;
let time_spawn_asteroid = 2.;; (*secondes*)
let current_stage_asteroids = ref 3;;
let time_since_last_spawn = ref 9.5;;

(*Caract�ristiques des fragments. Principalement h�rit� des parents.*)
let fragment_max_velocity = 2500.;; (*Velocit� max au spawn*)
let fragment_min_velocity = 1500.;; (*Velocit� min au spawn*)
let fragment_max_size = 0.7 ;;(*En ratio de la taille de l'ast�ro�de parent*)
let fragment_min_size = 0.4;; (*En ratio de la taille de l'ast�ro�de parent*)
let fragment_min_exposure = 0.666;;
let fragment_max_exposure = 1.5;;
let fragment_number = 5;;
let fragment_min_repulsion = 100.;;
let fragment_min_bounce = 1000.;;
let chunk_max_size = 50.;;
let chunks = ref true;;
let chunk_radius_decay = 25.;; (*Pour la d�croissance des particules n'ayant pas de collisions*)


let nb_chunks_explo = 15;;
let chunks_explo_min_radius = 150.;;
let chunks_explo_max_radius = 300.;;
let chunks_explo_min_speed = 10000.;;
let chunks_explo_max_speed = 20000.;;
let chunk_explo_radius_decay = 500.;;

(*Param�tres du vaisseau*)
(*Pour l'autoregen*)
let autoregen = true;;
let autoregen_health = 5.;;(*Regain de vie par seconde*)
(*valeurs du vaisseau*)
let ship_max_health = 100.;; (*health au spawn. Permet de l'appliquer au mod�le physique.*)
let ship_max_lives = 3 ;;(*Nombre de fois que le vaisseau peut r�appara�tre*)
let ship_density = 100.;; (*Pour calcul de la masse du vaisseau, qui a un impact sur la physique*)
let ship_radius = 25.;; (*Pour la hitbox et le rendu*)
(*R�duction des d�gats et d�gats physiques*)
let ship_dam_ratio = 0.8;;
let ship_dam_res = 10.;;
let ship_phys_ratio = 0.005;;
let ship_phys_res = 0.;;
let ship_death_max_momentum = 2.;;
(*Contr�les de d�placement*)
let ship_max_depl = 50. ;;(*En px.s??. Utile si contr�le direct du d�placement.*)
let ship_max_accel = 10000. ;;(*En px.s?? Utile si contr�le de l'acc�l�ration*)
let ship_max_boost = 2000. ;;(*En px.s??. Utile si contr�le par boost.*)
let ship_half_stop = 10. ;;(*En temps n�cessaire pour perdre la moiti� de l'inertie*)
(*Contr�les de rotation*)
let ship_max_tourn = 4.;; (*En radian.s??*)
let ship_max_moment = 0.5;; (*En radian.s??*)
let ship_max_tourn_boost = 3.;;(*En radians.s??*)
let ship_max_rotat = pi /. 6.;;(*En radians*)
let ship_half_stop_rotat = 0.2;;(*En temps n�cessaire pour perdre la moiti� du moment angulaire*)
(*Temps min entre deux t�l�portations al�atoires*)
let cooldown_tp = 5.;;
let tp_time_invic = 1.;;(*Temps d'invincibilit� apr�s tp. *)
let time_last_tp = ref 0.;;

(*Valeurs du projectile*)
let projectile_recoil = ref 500.;; (*Recul appliqu� au vaisseau*)
let projectile_cooldown = ref 0.5;; (*Temps minimum entre deux projectiles*)
let projectile_max_speed = ref 15000.;;(*Vitesse relative au lanceur lors du lancement*)
let projectile_min_speed = ref  8000.;;
let projectile_herit_speed = true;;
let projectile_deviation = ref 0.3;;(*D�viation possible de la trajectoire des projectiles*)
let projectile_radius = ref 15.;;
let projectile_radius_hitbox = ref 20.;; (*On fait une hitbox plus grande pour �tre g�n�reux sur les collisions*)
let projectile_health = 0.;;(*On consid�re la mort quand la health descend sous z�ro. On a ici la certitude que le projectile se d�truira*)
let projectile_number = ref 50;;
let projectile_number_default = 5;;
let explosion_damages_projectile = 5000.;;

(*Shotgun*)
let shotgun_recoil = 1000.;;
let shotgun_cooldown = 0.3;;
let shotgun_max_speed = 15000.;;
let shotgun_min_speed = 10000.;;
let shotgun_deviation = 0.3;;
let shotgun_radius = 15.;;
let shotgun_radius_hitbox = 50.;;
let shotgun_number = 50;;
let oldschool = ref false;;
let retro = ref false;;

(*Valeurs des explosions*)
let explosion_max_radius = 250.;;
let explosion_min_radius = 200.;;
let explosion_min_exposure = 0.4;;(*D�termine la luminosit� max et min des explosions au spawn*)
let explosion_max_exposure = 1.3;;

let explosion_damages_objet =   50.;;
let explosion_damages_chunk = 150.;;
let explosion_damages_death =  50.;; (*by second*)

(*Pour les explosions h�ritant d'un objet*)
let explosion_ratio_radius = 2.;;
let explosion_death_max_radius = 150.;;
let explosion_death_min_radius = 100.;;
let explosion_saturate = 10.;;
let explosion_min_exposure_heritate = 2.;;
let explosion_max_exposure_heritate = 6.;;

(*Valeurs des muzzleflashes*)
let muzzle_ratio_radius = 3.;;
let muzzle_ratio_speed = 0.05;;

(*Valeurs du feu � l'arri�re du vaisseau*)
let fire_max_random = 100.;;
let fire_min_speed = 500.;;
let fire_max_speed = 1000.;;
let fire_ratio_radius = 1.4;;

(*Valeurs de la fum�e*)
let smoke = ref true;;
let smoke_half_col = 0.3;; (*Vitesse de la d�croissance de la couleur*)
let smoke_half_radius = 0.5 ;;(*Vitesse de la d�croissance du rayon*)
let smoke_radius_decay = 5.;; (*Diminution du rayon des particules de fum�e*)
let smoke_max_speed = 400.;;(*Vitesse random dans une direction random de la fum�e*)


(*Valeurs des �toiles*)
let star_min_prox = 0.3;;(*Prox min des �toiles. 0 = �toile � l'infini, para�t immobile quel que soit le mouvement.*)
let star_max_prox = 0.9;; (*Prox max. 1 = m�me profondeur que le vaisseau *)
let star_prox_lum = 5.;;(*Pour ajouter de la luminosit� aux �toiles plus proches*)
let star_min_lum = 0.;;
let star_max_lum = 4.;;
let star_rand_lum = 2.;; (*Effet de scintillement des �toiles*)
let stars_nb_default = 100;;
let stars_nb = ref 200;;
let stars_nb_previous = ref 200;;

(*La camera predictive oriente la camera vers l'endroit o� le vaisseau va,
pour le garder tant que possible au centre de l'�cran*)
let camera_prediction    = 2.5;; (*En secondes de d�placement du vaisseau dans le futur.*)
let camera_half_depl     = 1.5;; (*Temps pour se d�placer de moiti� vers l'objectif de la cam�ra*)
let camera_ratio_objects = 0.4;; (*La cam�ra va vers la moyenne des positions des objets, pond�r�s par leur masse et leur distance au carr�*)
let camera_ratio_vision  = 0.25;; (*La cam�ra va vers l� o� regarde le vaisseau, � une distance correspondant au ratio x la largeur du terrain*)
let camera_start_bound   = 0.3 ;;(*En ratio de la taille de l'�cran : distance du bord � laquelle la cam�ra commence � se recentrer*)
let camera_max_force     = 3.;; (*En ratio de la taille de l'�cran : vitesse appliqu�e � la cam�ra pour la recentrer si on ATTEINT le bord de l'�cran*)

(*Le screenshake ajoute des effets de tremblements � l'intensit� d�pendant  des �v�nements*)
let screenshake = ref true;;
let screenshake_smooth = true;; (*Permet un screenshake moins agressif, plus lisse et r�aliste physiquement. Sorte de passe-bas sur les mouvements*)
let screenshake_smoothness = 0.8 ;;(*0 = aucun changement, 0.5 =  1 = lissage infini, screenshake supprim�.*)
let screenshake_tir_ratio = 400.;;
let screenshake_death = 6000.;;
let screenshake_dam_ratio = 0.005;;
let screenshake_phys_ratio = 0.005;;
let screenshake_phys_mass = 100000.;;(*Masse de screenshake �normal�. Des objets plus l�gers en provoqueront moins, les objets plus lourds plus*)
let screenshake_half_life = 0.1;;
let game_screenshake = ref 0.;;
let game_screenshake_pos = ref (0.,0.);;
let game_screenshake_previous_pos = ref (0.,0.);; (*Permet d'avoir un rendu correct des train�es de lumi�res lors du screenshake*)
(*Utilisation de l'augmentation du score pour faire trembler les chiffres*)
let shake_score = ref 0.;;
let shake_score_ratio = 0.2;;
let shake_strength = 0.01;;
let shake_score_half_life = 0.2;;



(*L'antialiasing de jitter fait �trembler� l'espace de rendu.
C'est une forme de dithering spatial
afin de compenser la perte de pr�cision due � la rast�risation
lors du placement des objets et du trac� des contours.*)
let dither_aa = true;;
(*La puissance du jitter d�termine � quel point le rendu peut se d�caler.*)
(*D�terminer � 1 ou moins pour �viter un effet de flou et de fatigue visuelle*)
let dither_power = 0.5;; (*En ratio de la taille d'un pixel*)
let dither_power_radius = 0.5;;
(*Le jitter double courant permet de faire le m�me jitter sur les positions d'objets.
Cela permet de s'assurer une consistance spatiale dans tout le rendu.*)
let current_jitter_double = ref (0.,0.);;
let current_jitter_coll_table = ref (0.,0.);;

(*L'exposition variable permet des variations de luminosit� en fonction des �v�nements*)
let variable_exposure = ref true;;
let exposure_ratio_damage = 0.995;;
let exposure_tir = 0.98;;
let exposure_ratio_explosions = 0.99;;
let exposure_half_life = 0.5;;
let game_exposure_target_death = 1.5;;
let game_exposure_target_boucle = 2.;;
let game_exposure_tp = 0.25;;
let game_exposure_target = ref 2.;;
let game_exposure = ref 0.;;

(*Flashes lumineux lors d'�v�nements*)
let flashes = ref true;;
let flashes_damage = 0.;;
let flashes_explosion = 0.02;;
let flashes_saturate = 10.;;
let flashes_normal_mass = 100000.;;
let flashes_tir =1.;;
let flashes_teleport = 100.;;
let flashes_death = 200.;;
let flashes_half_life = 0.01;;





(*FUntions*)
(******************************************************************************)
(*D�finition des fonctions d'ordre g�n�ral*)

(*Fonction de random float entre 2 valeurs*)
let randfloat min max = min +. Random.float (max -. min);;

(*Fonction de carre, pour �crire plus jolimment les formules de pythagore*)
let carre v = v *. v;;

(*Fonction de d�croissance exponentielle de n au bout de t secondes en float. Bas�e sur le temps ingame*)
let exp_decay n half_life proper_time = n *. 2. ** (!observer_proper_time *. !game_speed *. (!time_last_frame -. !time_current_frame) /. (proper_time *. half_life));;

(*Fonction de d�croissance exponentielle de n au bout de t secondes en float. Bas�e sur le temps r�el, pas sur le temps de jeu*)
let abso_exp_decay n half_life = n *. 2. ** ((!time_last_frame -. !time_current_frame) /. half_life);;

(*pythagore*)
let hypothenuse (x, y) = sqrt (carre x +. carre y);;

(*Permet l'addition de deux tuples*)
let addtuple (x1, y1) (x2, y2) = (x1 +. x2, y1 +. y2);;

(*Permet la soustraction de deux tuples*)
let soustuple (x1, y1) (x2, y2) = (x1 -. x2, y1 -. y2);;

(*Permet la multiplication d'un tuple par un float*)
let multuple (x, y) ratio = (x *. ratio, y *. ratio);;

(*Moyenne de float*)
let moyfloat val1 val2 ratio = val1 *. ratio +. val2 *. (1. -. ratio);;

(*Moyenne de deux tuples. le ratio est la pond�ration du premier.*)
let moytuple tuple1 tuple2 ratio = (addtuple (multuple tuple1 ratio) (multuple tuple2 (1.-.ratio)));;

(*Permet la multiplication de deux termes s�par�s au sein d'un tuple*)
let multuple_parallel (x1,y1) (x2,y2) = (x1 *. x2, y1 *. y2);;

(*Permet de v�rifier qu'un tuple se trouve entre deux autres*)
let entretuple (x0,y0) (x1,y1) (x2,y2) = x0 > x1 && x0 < x2 && y0 > y1 && y0 < y2;;

(*Permet de convertir un tuple de float en tuple de int*)
let inttuple (x, y) = (int_of_float x, int_of_float y);;

(*Permet de convertir un tuple de int en float*)
let floattuple (x, y) = (float_of_int x, float_of_int y);;

(*Application du dithering global avant conversion en int*)
let dither fl = if dither_aa then int_of_float (fl +. Random.float dither_power) else int_of_float fl;;

(*Application du dithering global avant conversion en int*)
let dither_radius fl = if dither_aa then int_of_float (fl -. 0.5 +. Random.float dither_power_radius) else int_of_float fl;;

(*Permet un dithering suivant le dithering global sur un tuple. Permet une meilleure consistance visuelle entre �l�ments �dither�s�*)
let dither_tuple (x,y) = if dither_aa then inttuple (addtuple !current_jitter_double (x,y)) else inttuple (x,y);;


(*Permet l'addition de deux tuples, en pound�rant le second par le ratio*)
let proj tuple1 tuple2 ratio = addtuple tuple1 (multuple tuple2 ratio);;

(*Transfert d'un vecteur en angle*valeur en x*y*)
let polar_to_affine angle valeur = (valeur *. cos angle, valeur *. sin angle);;

(*Transfert d'un vecteur en angle*valeur en x*y*)
let polar_to_affine_tuple (angle, valeur) = polar_to_affine angle valeur;;

(*Transfert d'un vecteur en x*y en angle*valeur *)
let affine_to_polar (x, y) =
let r = hypothenuse (x, y) in
if r = 0. then (0., 0.) (*Dans le cas o� le rayon est nul, on ne peut pas d�terminer d'angle donn�*)
else (2. *. atan (y /. (x +. r)),r);;

(*La fonction distancecarre est plus simple niveau calcul qu'une fonction distance,*)
(*Car on �vite la racine carr�e, mais n'en reste pas moins utile pour les hitbox circulaires*)
let distancecarre (x1, y1) (x2, y2) = carre (x2 -. x1) +. carre (y2 -. y1);;

let modulo_float value modulo = if value < 0. then value +. modulo else if value >= modulo then value -. modulo else value;;

(*Modulo pour le recentrage des �toiles*)
let modulo_reso (x, y) = (modulo_float x !phys_width, modulo_float y !phys_height);;

(*Modulo pour le recentrage des objets hors de l'�cran.
On consid�re une surface de 3x3 la surface de jeu.*)
(*� consid�rer : un espace carr� pour avoir un gameplay ind�pendant du ratio*)
let modulo_3reso (x, y) =
  ((modulo_float (x +. !phys_width ) (!phys_width  *. 3.)) -. !phys_width,
   (modulo_float (y +. !phys_height) (!phys_height *. 3.)) -. !phys_height);;


let diff l1 l2 = List.filter (fun x -> not (List.mem x l2)) l1;;



(*COLORS*)
(*Fonctions sur les couleurs*)
(******************************************************************************)

(*Syst�me de couleur*)
(*Pas de limite arbitraire de luminosit�. Les n�gatifs donnent du noir et sont accept�s.*)
type hdr = {r : float ; v : float ; b : float;};;

let hdr_add col1 col2 = {r = col1.r +. col2.r; v = col1.v +. col2.v; b = col1.b +. col2.b;};;
let hdr_sous col1 col2 = {r = col1.r -. col2.r; v = col1.v -. col2.v; b = col1.b -. col2.b;};;
let hdr_mul col1 col2 = {r = col1.r *. col2.r; v = col1.v *. col2.v; b = col1.b *. col2.b;};;

(*couleur additive pour �claircir toute l'image*)
let add_color = ref {r=0.;v=0.;b=0.};;
let mul_base = ref {r=1.;v=1.;b=1.};;
let mul_color = ref {r=0.;v=0.;b=0.};;

(*Fonction d'intensit� lumineuse d'une couleur hdr*)
let intensify hdr_in i = {r = i*. hdr_in.r ; v = i *. hdr_in.v ; b = i *. hdr_in.b};;

let half_color col1 col2 half_life = (hdr_add col2 {
	r = (abso_exp_decay (col1.r -. col2.r) half_life);
	v = (abso_exp_decay (col1.v -. col2.v) half_life);
	b = (abso_exp_decay (col1.b -. col2.b) half_life)});;

(*Redirige la saturation d'une couleur vers les couleurs proches*)
let redirect_spectre col = {
	r = if col.v > 255. then col.r +. col.v -. 255. else col.r;
	v = if col.b > 255. && col.r > 255. then col.v +. col.r +. col.b -. 510.
	    else if col.r > 255. then col.v +. col.r -. 255.
	    else if col.b > 255. then col.v +. col.b -. 255.
	    else col.v;
	b = if col.v > 255. then col.b +. col.v -. 255. else col.b};;

(*M�me chose, mais redirige encore plus loin en cas de saturation extr�me*)
let redirect_spectre_wide col = {
	r = if col.b > 510. then (
			if col.v > 255. then col.r +. col.v +. col.b -. 510. -. 255. else col.r +. col.b -. 510.
	    ) else (
			if col.v > 255. then col.r +. col.v -. 255. else col.r
	    );
	v = if col.b > 255. && col.r > 255. then col.v +. col.r +. col.b -. 510.
	    else if col.r > 255. then col.v +. col.r -. 255.
	    else if col.b > 255. then col.v +. col.b -. 255.
	    else col.v;
	b = if col.r > 510. then (
			if col.v > 255. then col.r +. col.v +. col.b -. 510. -. 255. else col.r +. col.b -. 510.
	    ) else (
			 if col.v > 255. then col.v +. col.b -. 255. else col.b
	    );};;


(*Conversion de couleur_hdr vers couleur*)
let rgb_of_hdr hdr =
  let hdr_mod = redirect_spectre_wide (hdr_mul (hdr_add hdr (intensify !add_color !game_exposure)) !mul_color)in
	let normal_color fl = max 0 (min 255 (int_of_float fl)) in (*Fonction ramenant entre 0 et 255, qui sont les bornes du sRGB*)
	rgb (normal_color hdr_mod.r) (normal_color hdr_mod.v) (normal_color hdr_mod.b);;

(*Fonction de saturation de la couleur*)
(*i un ratio entre 0 (N&B) et ce que l'on veut comme intensit� des couleurs.*)
(*1 ne change rien*)
let saturate hdr_in i =
  let value = (hdr_in.r +. hdr_in.v +. hdr_in.b) /. 3. in
  {r = i *. hdr_in.r +. ((1. -. i) *. value); v = i *. hdr_in.v +. ((1. -. i) *. value); b= i *. hdr_in.b +. ((1. -. i) *. value)};;

let space_color = ref {r = 0.; v = 0.; b = 0.};;
let space_color_goal = ref {r = 0.; v = 0.; b = 0.};;
let star_color = ref {r = 0.; v = 0.; b = 0.};;
let star_color_goal = ref {r = 0.; v = 0.; b = 0.};;



(*Objects*)
(******************************************************************************)
type type_object = Asteroid | Projectile | Ship | Explosion | Smoke | Spark | Shotgun (* | Sniper | Machinegun*);;

(*Polygone pour le rendu et les collisions. Liste de points en coordon�es polaires autour du centre de l'objet.*)
type polygon = (float*float) list;;

(*Pour les calculs de collision*)
type hitbox = {
  mutable ext_radius : float;
  mutable int_radius : float;
  mutable points : polygon; (*Liste des points pertinents pour calculer la collision. Angle * distance *)
};;


(*Pour les calculs de visuels*)
type visuals = {
  mutable color : hdr;
  mutable radius : float;
  mutable shapes : (hdr*polygon) list;
};;

type objet_physique = {
  objet : type_object;
  hitbox : hitbox;
  visuals : visuals;
  mutable mass : float;
  mutable health : float;
  mutable max_health : float;
  (*Fonction de r�sistance physique et aux dommages*)
  dam_ratio : float; (*ratio des degats bruts r�ellements inflig�s*)
  dam_res : float; (*R�duction des d�gats bruts.*)
  phys_ratio : float; (*ratio des d�gats physiques r�ellement inflig�s*)
  phys_res : float; (*R�duction des d�gats physiques, pour que les collisions � faible vitesse ne fassent pas de d�gats*)

  mutable position : (float*float);(*En pixels non entiers*)
  mutable velocity : (float*float);(*En pixels.s??*)

  (*orientation en radians, moment en radians.s??*)
  mutable orientation : float;
  mutable moment : float;

  mutable proper_time : float;
  mutable hdr_exposure : float;
};;

(*Pour l'arri�re-plan �toil�*)
type star = {
  mutable last_pos : (float*float);(*La position pr�c�dente permet de calculer correctement le motion_blur*)
  mutable pos : (float*float); (*Si on l'appelle pos, toutes les fonctions appelant objet_physique.position ralent comme quoi star n'est pas un objet physique.*)
  proximity : float;(*Proximit� avec l'espace de jeu.
  � 1, se situe sur le m�me plan que le vaisseau, � 0, � une distance infinie.
  Correspond simplement au ratio de d�placement lors du mouvement cam�ra*)
  lum : float;
};;





(*Aspect visuel du vaisseau*)
let visuals_ship = {
  color = {r=1000.;v=100.;b=25.};
  radius = ship_radius *. 0.9;
  shapes =
    [({r=200.;v=20.;b=20.},
      [(0.,3.*.ship_radius);
      (3. *. pi /. 4.,2.*.ship_radius);
      (pi,ship_radius);
      (~-.3. *. pi /. 4.,2.*.ship_radius)]);

    ({r=250.;v=25.;b=25.},
      [(0.,3.*.ship_radius);
      (pi,ship_radius);
      (~-.3. *. pi /. 4.,2.*.ship_radius)]);

    ({r=120.;v=5.;b=5.},
      [(0.,3.*.ship_radius);
      (3. *. pi /. 4.,2.*.ship_radius);
      (pi,ship_radius)]);

    ({r=10.;v=10.;b=10.},
      [(pi,ship_radius/.3.);
      (pi,ship_radius);
      (~-.3. *. pi /. 4.,2.*.ship_radius)]);

    ({r=30.;v=30.;b=30.},
      [(pi,ship_radius/.3.);
      (3. *. pi /. 4.,2.*.ship_radius);
      (pi,ship_radius)]);

    ({r=200.;v=180.;b=160.},
      [(0.,3.*.ship_radius);
      (0.,1.5*.ship_radius);
      (~-.pi /. 8.,1.5*.ship_radius)]);

    ({r=20.;v=30.;b=40.},
      [(0.,3.*.ship_radius);
      (pi /. 8.,1.5*.ship_radius);
      (0.,1.5*.ship_radius)])
    ];
};;

let hitbox_ship = {
  ext_radius = 3. *. ship_radius;
  int_radius = ship_radius;
  points = [(0.,3.*.ship_radius);
  (3. *. pi /. 4.,2.*.ship_radius);
  (pi,ship_radius);
  (~-.3. *. pi /. 4.,2.*.ship_radius)];
};;

(*Cr�ation du vaisseau*)
let spawn_ship () = {
    objet = Ship;
    visuals = visuals_ship;
    hitbox = hitbox_ship;
    mass = pi *. (carre ship_radius) *. ship_density;
    health = ship_max_health;
    max_health = ship_max_health;

    dam_ratio = ship_dam_ratio;
    dam_res = ship_dam_res;
    phys_ratio = ship_phys_ratio;
    phys_res = ship_phys_res;

    position = (!phys_width /. 2., !phys_height /. 2.);
    velocity = (0.,0.);

    orientation = pi /. 2.;
    moment = 0.;

    proper_time = 1.;
    hdr_exposure = 1.;
};;


let spawn_projectile position velocity proper_time = {
    objet = Projectile;

    visuals = {
      color = {r=2000.;v=400.;b=200.};
      radius = !projectile_radius;
      shapes = [];
    };

    hitbox = {
      int_radius = !projectile_radius_hitbox;
      ext_radius = !projectile_radius_hitbox;
      points = [];
    };

    mass = 10000.;
    health = projectile_health;
    max_health = projectile_health;
    (*Les projectiles sont con�us pour �tre d�truits au contact*)
    dam_res = 0.;
    dam_ratio = 1.;
    phys_res = 0.;
    phys_ratio = 1.;

    position = position;
    velocity = velocity;

    orientation = 0.;
    moment = 0.;

    proper_time = proper_time;
    hdr_exposure = 4.;
};;

(*Permet de cr�er n projectiles*)
let rec spawn_n_projectiles ship n =
  if n = 0 then [] else (
  let vel = if projectile_herit_speed
    then addtuple ship.velocity (polar_to_affine (((Random.float 1.) -. 0.5) *. !projectile_deviation +. ship.orientation) (!projectile_min_speed +. Random.float (!projectile_max_speed -. !projectile_min_speed)))
    else (polar_to_affine (((Random.float 1.) -. 0.5) *. !projectile_deviation +. ship.orientation) (!projectile_min_speed +. Random.float (!projectile_max_speed -. !projectile_min_speed)))
  and pos = addtuple ship.position (polar_to_affine ship.orientation ship.hitbox.ext_radius) in (*On fait spawner les projectiles au bout du vaisseau*)
  ref (spawn_projectile pos vel ship.proper_time) :: spawn_n_projectiles ship (n-1))



  let spawn_chunk_explo position velocity color proper_time = {
      objet = Asteroid;

      visuals = {
        color = color;
        radius = chunks_explo_min_radius +. Random.float (chunks_explo_max_radius -. chunks_explo_min_radius);
        shapes = [];
      };

      hitbox = {
        int_radius = 0.;
        ext_radius = 0.;
        points = [];
      };

      mass = 100.;
      health = projectile_health;
      max_health = projectile_health;
      (*Les projectiles sont con�us pour �tre d�truits au contact*)
      dam_res = 0.;
      dam_ratio = 1.;
      phys_res = 0.;
      phys_ratio = 1.;

      position = position;
      velocity = velocity;

      orientation = 0.;
      moment = 0.;

      proper_time = proper_time;
      hdr_exposure = 4.;
  };;

  (*Permet de cr�er n projectiles*)
  let rec spawn_n_chunks ship n color =
    if n = 0 then [] else (
    let vel = addtuple ship.velocity (polar_to_affine (Random.float (2. *. pi)) (chunks_explo_min_speed +. Random.float (chunks_explo_max_speed -. chunks_explo_min_speed)))
      and pos = ship.position in
    ref (spawn_chunk_explo pos vel color ship.proper_time) :: spawn_n_chunks ship (n-1) color);;


(*Spawne une explosion d'impact de projectile*)
let spawn_explosion ref_projectile =
  let rad = explosion_min_radius +. (Random.float (explosion_max_radius -. explosion_min_radius)) in
  let rand_lum = (randfloat explosion_min_exposure explosion_max_exposure) in
  ref {
  objet = Explosion;
  visuals = {
    color = intensify {
      r = 2000.;
      v = 500. ;
      b = 200.}
    rand_lum;
    radius = rad;
    shapes = [];
  };
  hitbox = {
    int_radius = rad;
    ext_radius = rad;
    points = [];
  };
  mass = explosion_damages_projectile;
  health = 0.;
  max_health = 0.;

  dam_res = 0.;
  dam_ratio = 0.;
  phys_res = 0.;
  phys_ratio = 0.;

  position = !ref_projectile.position;
  velocity = polar_to_affine (Random.float 2. *. pi) (Random.float smoke_max_speed);
  orientation = 0.;
  moment = 0.;

  proper_time = 1.;
  hdr_exposure = 1.;
};;


(*Spawn une explosion h�ritant d'un objet d'une taille au choix.*)
let spawn_explosion_object ref_objet =
  let rad = explosion_ratio_radius *. !ref_objet.hitbox.int_radius in (*On r�cup�re le rayon de l'objet*)
  if !flashes then add_color := hdr_add !add_color (intensify (saturate !ref_objet.visuals.color flashes_saturate) (!ref_objet.mass *. flashes_explosion *. (randfloat explosion_min_exposure_heritate explosion_max_exposure_heritate) /. flashes_normal_mass));
  if !variable_exposure then game_exposure := !game_exposure *. exposure_ratio_explosions;
  ref {
  objet = Explosion;
  visuals = {
    color = intensify (saturate !ref_objet.visuals.color explosion_saturate) (randfloat explosion_min_exposure_heritate explosion_max_exposure_heritate);
    radius = rad;
    shapes = [];
  };
  hitbox = {
    int_radius = rad;
    ext_radius = rad;
    points = [];
  };
  mass = explosion_damages_objet;
  health = 0.;
  max_health = 0.;

  dam_res = 0.;
  dam_ratio = 0.;
  phys_res = 0.;
  phys_ratio = 0.;

  position = !ref_objet.position;
  (*On donne � l'explosion une vitesse random, afin que la fum�e qui en d�coule en h�rite*)
  velocity = polar_to_affine (Random.float 2. *. pi) (Random.float smoke_max_speed);
  orientation = 0.;
  moment = 0.;

  proper_time = !ref_objet.proper_time;
(*La nouvelle exposition est partag�e entre couleur et exposition, pour que la fum�e ne finisse pas trop sombre*)

  hdr_exposure = randfloat explosion_min_exposure_heritate explosion_max_exposure_heritate ;
};;

(*Spawn une explosion h�ritant du vaisseau lors de sa mort*)
let spawn_explosion_death ref_ship elapsed_time =
  let rad = explosion_death_min_radius +. (Random.float (explosion_death_max_radius -. explosion_death_min_radius)) in
  let rand_lum = (randfloat explosion_min_exposure explosion_max_exposure) in
  ref {
  objet = Explosion;
  visuals = {
    color = intensify {
      r = 2000.;
      v = 500. ;
      b = 200.}
    rand_lum;
    radius = rad;
    shapes = [];
  };
  hitbox = {
    int_radius = rad;
    ext_radius = rad;
    points = [];
  };
  mass = explosion_damages_death *. elapsed_time;
  health = 0.;
  max_health = 0.;

  dam_res = 0.;
  dam_ratio = 0.;
  phys_res = 0.;
  phys_ratio = 0.;

  position = !ref_ship.position;
  (*On donne � l'explosion une vitesse random, afin que la fum�e qui en d�coule en h�rite*)
  velocity = polar_to_affine (Random.float 2. *. pi) (Random.float smoke_max_speed);
  orientation = 0.;
  moment = 0.;

  proper_time = !ref_ship.proper_time;
  hdr_exposure = 1.;
};;


let spawn_explosion_chunk ref_objet =
  let rad = explosion_ratio_radius *. !ref_objet.visuals.radius in (*On r�cup�re le rayon de l'objet*)
  if !flashes then add_color := hdr_add !add_color (intensify (saturate !ref_objet.visuals.color flashes_saturate) (!ref_objet.mass *. flashes_explosion *. (randfloat explosion_min_exposure_heritate explosion_max_exposure_heritate) /. flashes_normal_mass));
  (* if variable_exposure then game_exposure := !game_exposure *. exposure_ratio_explosions; *)
  ref {
  objet = Explosion;
  visuals = {
    color = !ref_objet.visuals.color;
    radius = rad;
    shapes = [];
  };
  hitbox = {
    int_radius = rad;
    ext_radius = rad;
    points = [];
  };
  mass = explosion_damages_chunk (*Replace with a function of time spent on frame*);
  health = 0.;
  max_health = 0.;

  dam_res = 0.;
  dam_ratio = 0.;
  phys_res = 0.;
  phys_ratio = 0.;

  position = !ref_objet.position;
  (*On donne � l'explosion une vitesse random, afin que la fum�e qui en d�coule en h�rite*)
  velocity = polar_to_affine (Random.float 2. *. pi) (Random.float smoke_max_speed);
  orientation = 0.;
  moment = 0.;

  proper_time = !ref_objet.proper_time;
(*La nouvelle exposition est partag�e entre couleur et exposition, pour que la fum�e ne finisse pas trop sombre*)

  hdr_exposure = explosion_min_exposure +. (Random.float (explosion_max_exposure -. explosion_min_exposure));
};;

(*Spawne un muzzleflash � la position donn�e*)
let spawn_muzzle ref_projectile = ref {
  objet = Smoke;
  visuals = {
    color = intensify !ref_projectile.visuals.color (randfloat explosion_min_exposure_heritate explosion_max_exposure_heritate);
    radius = muzzle_ratio_radius *. !ref_projectile.visuals.radius;
    shapes = [];
  };
  hitbox = {
    int_radius = 0.;
    ext_radius = 0.;
    points = [];
  };
  mass = 0.;
  health = 0.;
  max_health = 0.;

  dam_res = 0.;
  dam_ratio = 0.;
  phys_res = 0.;
  phys_ratio = 0.;

  position = !ref_projectile.position;
  velocity = multuple !ref_projectile.velocity muzzle_ratio_speed;
  orientation = 0.;
  moment = 0.;

  proper_time = !ref_projectile.proper_time;
  hdr_exposure = explosion_min_exposure +. (Random.float (explosion_max_exposure -. explosion_min_exposure));
};;


(*Spawne du feu � l'arri�re d'un vaisseau acc�l�rant*)
let spawn_fire ref_ship = ref {
  objet = Smoke;
  visuals = {
    color = {r = 1500. ; v = 400. ; b = 200. };
    radius = fire_ratio_radius *. !ref_ship.hitbox.int_radius;
    shapes = [];
  };
  hitbox = {
    int_radius = 0.;
    ext_radius = 0.;
    points = [];
  };
  mass = 0.;
  health = 0.;
  max_health = 0.;

  dam_res = 0.;
  dam_ratio = 0.;
  phys_res = 0.;
  phys_ratio = 0.;

  position = addtuple !ref_ship.position (polar_to_affine (!ref_ship.orientation +. pi) !ref_ship.hitbox.int_radius);
  velocity = addtuple !ref_ship.velocity (addtuple (polar_to_affine (!ref_ship.orientation +. pi) (fire_min_speed +. (Random.float (fire_max_speed -. fire_min_speed)))) (polar_to_affine (Random.float 2. *. pi) (Random.float fire_max_random)));
  orientation = 0.;
  moment = 0.;

  proper_time = !ref_ship.proper_time;
  hdr_exposure = explosion_min_exposure +. (Random.float (explosion_max_exposure -. explosion_min_exposure));
};;



let rec polygon_asteroid radius n =
  let nb_sides = max asteroid_polygon_min_sides (int_of_float (asteroid_polygon_size_ratio *. radius)) in
  if n = 1
    then ([(2. *. pi *. (float_of_int n) /. (float_of_int nb_sides)), radius *. (randfloat asteroid_polygon_min asteroid_polygon_max)])
    else ((2. *. pi *. (float_of_int n) /. (float_of_int nb_sides)), radius *. (randfloat asteroid_polygon_min asteroid_polygon_max)) :: polygon_asteroid radius (n-1);;


let spawn_asteroid (x, y) (dx, dy) radius =
  let shape = polygon_asteroid radius (max asteroid_polygon_min_sides (int_of_float (asteroid_polygon_size_ratio *. radius)))
  and color = saturate {
    r = randfloat asteroid_min_lum asteroid_max_lum ;
    v = randfloat asteroid_min_lum asteroid_max_lum ;
    b = randfloat asteroid_min_lum asteroid_max_lum}
      (randfloat asteroid_min_satur asteroid_max_satur);
  in
{
  objet = Asteroid;
  visuals = {
    color = color;
    radius = radius;
    shapes =  [(color,shape)];
  };
  hitbox = {
    int_radius = radius;
    ext_radius = radius *. asteroid_polygon_max;
    points = shape;
  };
  mass = pi *. (carre radius) *. asteroid_density;
  health = asteroid_mass_health *. pi *. (carre radius) *. asteroid_density +. asteroid_min_health;
  max_health = asteroid_mass_health *. pi *. (carre radius) *. asteroid_density +. asteroid_min_health;

  dam_res = asteroid_dam_res;
  dam_ratio = asteroid_dam_ratio;
  phys_res = asteroid_phys_res;
  phys_ratio = asteroid_phys_ratio;

  position = (x, y);
  velocity = (dx, dy);
  orientation = Random.float (2. *. pi);
  moment = Random.float (2. *. asteroid_max_moment) -. asteroid_max_moment ;

  proper_time = 1.;
  hdr_exposure = 1.;
};;


(*Permet de donner des coordon�es telles que l'objet n'apparaisse pas dans l'�cran de jeu.*)
let rec random_out_of_screen radius =
  let (x,y) = ((Random.float ( 3. *. !phys_width)) -. !phys_width, (Random.float ( 3. *. !phys_height)) -. !phys_height) in
  if (y +. radius > 0. && y -. radius < !phys_height && x +. radius > 0. && x -. radius < !phys_width) then  random_out_of_screen radius else (x,y)

let spawn_random_star () =
let randpos = (Random.float !phys_width, Random.float !phys_height) in {
 last_pos = randpos;
 pos = randpos;
 proximity = (randfloat star_min_prox star_max_prox) ** 4.;
 lum = randfloat star_min_lum star_max_lum;
}

let rec n_stars n =
 if n=0 then [] else (ref (spawn_random_star ()) :: n_stars (n-1));;

 let checkspawn_objet ref_objet_unspawned =
   let objet = !ref_objet_unspawned in
   let (x, y) = objet.position in
   let rad = objet.hitbox.ext_radius in
  (x -. rad < !phys_width) && (x +. rad > 0.) && (y -. rad < !phys_height) && (y +. rad > 0.)
 let checknotspawn_objet ref_objet_unspawned = not (checkspawn_objet ref_objet_unspawned)
 let close_enough ref_objet = hypothenuse (soustuple !ref_objet.position (!phys_width /. 2., !phys_height /. 2.)) < max_dist
 let too_far ref_objet = not (close_enough ref_objet)
 let close_enough_bullet ref_objet = hypothenuse !ref_objet.position < max_dist
 let too_small ref_objet = !ref_objet.hitbox.ext_radius < asteroid_min_size
 let big_enough ref_objet = not (too_small ref_objet)
 let positive_radius ref_objet = !ref_objet.visuals.radius > 0.
 let ischunk ref_objet = !ref_objet.hitbox.int_radius < chunk_max_size
 let notchunk ref_objet = !ref_objet.hitbox.int_radius >= chunk_max_size;;




(*Buttons*)
(******************************************************************************)


(*Types pour les boutons du menu*)
type buttonboolean = {
  pos1 : (float*float); (*Coin 1 du bouton*)
  pos2 : (float*float); (*Coin 2*)
  text : string; (*Texte � afficher dans le bouton*)
  text_over : string;
  boolean : bool ref; (*R�f�rence du bool�en � modifier*)
  mutable lastmousestate : bool; (*Permet de v�rifier qu'� l'image pr�c�dente la souris �tait cliqu�e ou pas, afin d'�viter qu'� chaque frame le bool�en soit chang�*)
};;

(*Type pour des boutons sliders*)
type sliderfloat = {
  pos1 : (float*float); (*Coin 1 du bouton*)
  pos2 : (float*float); (*Coin 2*)
  text : string; (*Texte � afficher dans le bouton*)
  valeur : float ref;(*R�f�rence du float � modifier*)
  minval : float; (*Permet d'avoir une valeur plancher*)
  defaultval : float; (*Afficher la valeur par d�faut*)
  maxval : float; (*Permet d'avoir une valeur max*)
};;

(*Fonction permettant l'affichage du bouton et son activation*)
let applique_button button =
  ignore (button.boolean); (*Oblig� de faire �a pour que la fonction n'essaye pas de l'appliquer � sliderfloat*)
  let (x0,y0) = inttuple (multuple button.pos1 !ratio_rendu) and (l,h) = inttuple (multuple (soustuple button.pos2 button.pos1) !ratio_rendu)in
  if !retro then (
    if !(button.boolean) = true then set_color white else set_color black;
    fill_rect x0 y0 l h; (*Int�rieur du bouton*)
    set_color white; set_line_width 0; draw_rect x0 y0 l h; (*Contour du bouton*)
    let (wtext,htext) = text_size button.text in
    if !(button.boolean) = true then set_color black else set_color white;
    moveto (x0 + (l - wtext)/2 ) (y0 + (h - htext)/2 ); draw_string button.text
  ) else (
    if !(button.boolean) = true then set_color truecolor else set_color falsecolor;
    fill_rect x0 y0 l h; (*Int�rieur du bouton*)
    set_color buttonframe; set_line_width buttonframewidth; draw_rect x0 y0 l h; (*Contour du bouton*)
    let (wtext,htext) = text_size button.text in
    set_color black; moveto (x0 + (l - wtext)/2 -1) (y0 + (h - htext)/2 -1); draw_string button.text;
    set_color white; moveto (x0 + (l - wtext)/2   ) (y0 + (h - htext)/2   ); draw_string button.text
  );
  (*On affiche le d�tail de ce que fait le bouton � c�t� de la souris*)
  if (entretuple (multuple (floattuple (mouse_pos ())) (1. /. !ratio_rendu)) button.pos1 button.pos2) then (
    let (x,y) = mouse_pos () in
    moveto (x-1) (y-1); set_color black; draw_string button.text_over;
    moveto x y; set_color white; draw_string button.text_over;
  );
  (*Si la souris est cliqu�e, ne l'�tait pas � la frame pr�c�dente, et est dans la surface du bouton*)
  if button_down () && not button.lastmousestate && (entretuple (multuple (floattuple (mouse_pos ())) (1. /. !ratio_rendu)) button.pos1 button.pos2)
    then button.boolean := not !(button.boolean);
  button.lastmousestate <- button_down ();;

(*Fonction permettant l'affichage du bouton et son activation*)
let applique_slider ref_slider =
  let slider = !ref_slider in
  set_color slidercolor;
  let (x0,y0) = inttuple slider.pos1 and (l,h) = inttuple (soustuple slider.pos2 slider.pos1) in
  fill_rect x0 y0 l h; (*Int�rieur du slider*)
  set_color buttonframe; set_line_width buttonframewidth; fill_rect x0 y0 l h; (*Contour du slider*)
  (*Si la souris est cliqu�e, ne l'�tait pas � la frame pr�c�dente, et est dans la surface du bouton*)
  if (button_down () && (entretuple (multuple (floattuple (mouse_pos ())) (1. /. !ratio_rendu)) slider.pos1 slider.pos2))
    then (let (x,y) = mouse_pos () in slider.valeur := (moyfloat slider.maxval slider.minval (float_of_int (x-x0)))) else();
  ref_slider := slider;;


  let button_new_game={
    pos1 = ((4./.16.) *. !phys_width,(20./.24.) *. !phys_height);
    pos2 = ((6./.16.) *. !phys_width,(22./.24.) *. !phys_height);
    text = "New Game";
    text_over = "Start a new game with current parameters";
    boolean = restart;
    lastmousestate = false;};;

  let button_resume={
    pos1 = ((7./.16.) *. !phys_width,(20./.24.) *. !phys_height);
    pos2 = ((9./.16.) *. !phys_width,(22./.24.) *. !phys_height);
    text = "resume";
    text_over = "Resume current game";
    boolean = pause;
    lastmousestate = false;};;

  let button_quit={
    pos1 = ((10./.16.) *. !phys_width,(20./.24.) *. !phys_height);
    pos2 = ((12./.16.) *. !phys_width,(22./.24.) *. !phys_height);
    text = "quit";
    text_over = "Quit game";
    boolean = quit;
    lastmousestate = false;};;















(*Game*)
(******************************************************************************)

let even_frame = ref true;;
let evener_frame = ref true (*change toutes les 2 frames*)
let nb_collision_checked = ref 0;;

let collision_table=         Array.make (width_collision_table*height_collision_table) [];;
let collision_table_toosmall=Array.make (width_collision_table*height_collision_table) [];;
let collision_table_other=   Array.make (width_collision_table*height_collision_table) [];;
let collision_table_frag=    Array.make (width_collision_table*height_collision_table) [];;

type etat = {
  mutable buttons : buttonboolean list;
  mutable score : int;
  mutable lifes : int;
  mutable stage : int;
  mutable cooldown : float; (*Le cooldown est le temps restant avant de pouvoir de nouveau tirer*)
  mutable cooldown_tp : float; (*Le cooldown est le temps restant avant de pouvoir de nouveau tirer*)
  mutable last_health : float;
  mutable ref_ship : objet_physique ref;
  (*OOS = Out of screen, to avoid loss of time when rendering.*)
  mutable ref_objets : objet_physique ref list;
  mutable ref_objets_oos : objet_physique ref list;
  mutable ref_toosmall : objet_physique ref list;
  mutable ref_toosmall_oos : objet_physique ref list;
  mutable ref_fragments : objet_physique ref list;
  mutable ref_chunks : objet_physique ref list;
  mutable ref_chunks_oos : objet_physique ref list;
  mutable ref_chunks_explo : objet_physique ref list;
  mutable ref_projectiles : objet_physique ref list;
  mutable ref_explosions : objet_physique ref list;
  mutable ref_smoke : objet_physique ref list;
  mutable ref_smoke_oos : objet_physique ref list;
  mutable ref_sparks : objet_physique ref list;
  mutable ref_stars : star ref list;
};;

(*Rend un asteroeidee spawn random*)
let spawn_random_asteroid stage =
  spawn_asteroid
    (random_out_of_screen asteroid_max_spawn_radius)
    (polar_to_affine (Random.float 2. *. pi) (randfloat asteroid_min_velocity (asteroid_max_velocity +. asteroid_stage_velocity *. (float_of_int stage))))
    (randfloat asteroid_min_spawn_radius asteroid_max_spawn_radius);;


(*Diminution de la taille d'un asteroide*)
(*Permet de spawner plusieurs sous-asteroides lors de la fragmentation*)
let frag_asteroid ref_asteroid =
  let asteroid = !ref_asteroid in
  let fragment = spawn_asteroid asteroid.position asteroid.velocity asteroid.hitbox.int_radius in
  let orientation = (Random.float 2. *. pi) in
  let new_radius = (randfloat fragment_min_size fragment_max_size) *. fragment.hitbox.int_radius in
  let new_shape = polygon_asteroid new_radius (max asteroid_polygon_min_sides (int_of_float (asteroid_polygon_size_ratio *. new_radius))) in
  fragment.position <- addtuple fragment.position (polar_to_affine orientation (fragment.hitbox.int_radius -. new_radius));

  fragment.visuals.radius <- new_radius;
  fragment.visuals.color <- asteroid.visuals.color;
  fragment.visuals.shapes <- [(asteroid.visuals.color,new_shape)];

  fragment.hitbox.int_radius <- new_radius;
  fragment.hitbox.ext_radius <- new_radius *. asteroid_polygon_max;
  fragment.hitbox.points <- new_shape;

  fragment.mass <- pi *. asteroid_density *. (carre fragment.hitbox.int_radius);
  fragment.health <- asteroid_mass_health *. fragment.mass +. asteroid_min_health;
  fragment.max_health <- fragment.health;
  fragment.velocity <- addtuple fragment.velocity (polar_to_affine orientation (fragment_min_velocity +. Random.float (fragment_max_velocity -. fragment_min_velocity)));
  fragment.hdr_exposure <- fragment.hdr_exposure *. (fragment_min_exposure +. Random.float (fragment_max_exposure -. fragment_min_exposure));
  ref fragment;;



let init_etat () =  game_screenshake:=0. ;{
  buttons =
    [ button_quit ; button_resume ; button_new_game;
     (*button_scanlines ; button_retro ;
     button_hitbox ; button_smoke ; button_screenshake ;
     button_flashes ; button_chunks ; button_color*)];
  lifes = ship_max_lives;
  score = 0;
  stage = 0;
  cooldown = 0.;
  cooldown_tp = 0.;
  last_health = ship_max_health;
  ref_ship = ref (spawn_ship ());
  ref_objets = [];
  ref_objets_oos = [];
  ref_toosmall = [];
  ref_toosmall_oos = [];
  ref_fragments = [];
  ref_chunks = [];
  ref_chunks_oos = [];
  ref_chunks_explo = [];
  ref_projectiles = [];
  ref_explosions = [];
  ref_smoke = [];
  ref_smoke_oos = [];
  ref_sparks = [];
  ref_stars = n_stars !stars_nb;
};;



(*Rotation de polygone.*)
let rec rotat_poly poly rotat =
  let rotat_point (theta,rayon) rotat = (theta +. rotat,rayon) in
  if poly = [] then [] else [(rotat_point (List.hd poly) rotat)] @ (rotat_poly (List.tl poly) rotat);;

let rec scale_poly poly scale =
  let scale_point (theta,rayon) scale = (theta, rayon *. scale) in
  if poly = [] then [] else [(scale_point (List.hd poly) scale)] @ (scale_poly (List.tl poly) scale);;

let poly_to_affine poly rotat scale = List.map polar_to_affine_tuple (scale_poly (rotat_poly poly rotat) scale);;

let rec depl_affine_poly poly pos = if poly = [] then [] else (addtuple (List.hd poly) pos) :: (depl_affine_poly (List.tl poly) pos);;
let render_poly poly pos rotat color =
  let poly_to_render = depl_affine_poly (poly_to_affine poly rotat !ratio_rendu) pos in
  if !retro
    then (set_color white; set_line_width 0;draw_poly (Array.of_list (List.map dither_tuple poly_to_render)))
    else (set_color color; set_line_width 0;fill_poly (Array.of_list (List.map dither_tuple poly_to_render)));;

let rec render_shapes shapes pos rotat expos=
  match shapes with
  | [] -> ()
  | (hdcol,hdpoly)::tl ->
    (render_poly hdpoly pos rotat (rgb_of_hdr (intensify hdcol expos));
    render_shapes tl pos rotat expos);;

(*On dessine le polygone de l'objet.*)
let render_visuals objet offset =
  let visuals = objet.visuals in
  let position = (multuple (addtuple (addtuple objet.position !game_screenshake_pos) offset) !ratio_rendu) in
  if visuals.radius > 0. && not !retro then (
    set_color (rgb_of_hdr (intensify visuals.color (!game_exposure *. objet.hdr_exposure)));
    let (x,y) = dither_tuple position in
    fill_circle x y (dither_radius (visuals.radius *. !ratio_rendu))
  );
  render_shapes visuals.shapes position objet.orientation (!game_exposure *. objet.hdr_exposure);;

let render_objet ref_objet = render_visuals !ref_objet (0.,0.);;
let render_unspawned ref_objet = render_visuals !ref_objet (0.,0.);;

(*Permet de rendre un polygone ayant des points determines en pourcentage de largeur et hauteur
en points en int. (Avec dither le cas echeant)*)
let rec relative_poly points_list =
  if points_list = [] then [] else inttuple (multuple_parallel (List.hd points_list) (float_of_int width,float_of_int height)) :: (relative_poly (List.tl points_list));;


(*permet le rendu de motion blur sur des objets spheriques*)
(*Part de l'endroit ou un objet etait à l'etat precedent pour decider*)
let render_light_trail radius pos velocity hdr_color proper_time =
(*TODO corriger le fait que le shutter_speed ne semble pas avoir d'influence sur la longueur des trainees de lumiere dues au screenshake*)
  set_line_width (dither_radius (2.*.radius)); (*line_width en est le diamètre, d'ou la multiplication par 2 du rayon*)
  let pos1 = (multuple (addtuple pos !game_screenshake_pos) !ratio_rendu) in (*Position actuelle de l'objet*)
  let veloc = multuple velocity ~-. ((!observer_proper_time /. proper_time) *. !game_speed *. (max (1. /. framerate_render) (1. *.(!time_current_frame -. !time_last_frame)))) in (*On projette d'une distance dependant du temps depuis la dernière frame.*)
  let last_position = (multuple (soustuple (addtuple pos !game_screenshake_previous_pos) veloc) !ratio_rendu) in (*On calcule la position ou l'objet etait à la derniere frame en tenant compte de la velocite et du screenshake.*)
  let pos2 = moytuple last_position pos1 shutter_speed in (*Plus la shutter_speed s'approche de 1, plus on se rapproche effectivement du point de l'image precedente pour la trainee.*)
  set_color (rgb_of_hdr (intensify hdr_color (!game_exposure *. 0.5 *. (sqrt (radius /. (radius +. hypothenuse (soustuple pos1 pos2)))))));(*Plus la trainee de lumiere est grande par rapport au rayon de l'objet, moins la lumière est intense*)
  let (x1,y1) = dither_tuple pos1 in
  let (x2,y2) = dither_tuple pos2 in
  moveto x1 y1 ; lineto x2 y2;; (*On dessine le trait correspondant à la trainee.*)


(*Traine de lumiere des etoiles.*)
let render_star_trail ref_star =
  let star = !ref_star in
  let pos1 = (multuple (addtuple star.pos !game_screenshake_pos) !ratio_rendu) in
  let last_position = (multuple (addtuple star.last_pos (!game_screenshake_previous_pos)) !ratio_rendu) in
  let pos2 = moytuple last_position pos1 shutter_speed in
  let (x1,y1) = dither_tuple pos1 in
  let (x2,y2) = dither_tuple pos2 in
  let lum = if !pause then star.lum +. 0.5 *. star_rand_lum else star.lum +. Random.float star_rand_lum in
  let star_color_tmp = intensify !star_color (lum *. !game_exposure)  in
  if (x1 = x2 && y1 = y2) then ( (*Dans le cas ou letoile n'a pas bouge on rend plusieurs points, plutot qu'une ligne.*)

    set_color (rgb_of_hdr (intensify (hdr_add star_color_tmp !space_color) !game_exposure ));
    plot x1 y1;
      set_color (rgb_of_hdr (intensify star_color_tmp (0.25)));
      plot (x1+1) y1 ; plot (x1-1) y1 ; plot x1 (y1+1) ; plot x1 (y1-1); (*Pour rendre un peu plus large qu'un simple point*)
      set_color (rgb_of_hdr (intensify star_color_tmp (0.125)));
      plot (x1+1) (y1+1) ; plot (x1+1) (y1-1) ; plot (x1-1)  (y1+1) ; plot (x1-1)  (y1-1);
  )else (
    set_color (rgb_of_hdr
	(hdr_add
		(intensify star_color_tmp (sqrt (1. /. (1. +. hypothenuse (soustuple pos1 pos2)))))
		(hdr_add (intensify !space_color !game_exposure) (intensify !add_color !game_exposure))));(*Plus la trainee de lumiere est grande par rapport au rayon de l'objet, moins la lumiere est intense*)
    set_line_width 2 ; moveto x1 y1 ; lineto x2 y2);;



(*Rendu des chunks. Pas de duplicatas, pas d'affichage de la vie, et l'objet est plus sombre*)
let render_chunk ref_objet =
  let objet = !ref_objet in
  let (x,y) = dither_tuple (multuple (addtuple objet.position !game_screenshake_pos) !ratio_rendu) in
  if !retro then (
    set_color (rgb 128 128 128);
    fill_circle x y (dither_radius (0.25 *. !ratio_rendu *. objet.visuals.radius));
  ) else (
    let intensity_chunk = 1. in
    set_color (rgb_of_hdr (intensify objet.visuals.color (intensity_chunk *. !game_exposure *. objet.hdr_exposure)));
    fill_circle x y (dither_radius (!ratio_rendu *. objet.visuals.radius)));;


(*Rendu des projectiles. Dessine des trainees de lumiere.*)
let render_projectile ref_projectile =
  let objet = !ref_projectile in
  let visuals = objet.visuals in
  let rad = !ratio_rendu *. (randfloat 0.5 1.) *. visuals.radius in
  if !retro
    then (let (x,y) = dither_tuple (multuple objet.position !ratio_rendu) in
      set_color white; fill_circle x y (dither_radius rad))
    else (
      (*On récupere les valeurs qu'on va utiliser plusieurs fois *)
      let pos = objet.position and vel = objet.velocity
      and col = intensify visuals.color (objet.hdr_exposure *. !game_exposure) in
      (*On rend plusieurs traits concentriques pour un effet de degrade*)
      let proper_time = objet.proper_time in
      render_light_trail rad pos vel (intensify col 0.25) proper_time;
      render_light_trail (rad *. 0.75) pos vel (intensify col 0.5) proper_time;
      render_light_trail (rad *. 0.5) pos vel col proper_time;
      render_light_trail (rad *. 0.25) pos vel (intensify col 2.) proper_time);;

let render_spark ref_spark =
  let objet = !ref_spark in
  render_light_trail objet.visuals.radius objet.position objet.velocity (intensify objet.visuals.color (objet.hdr_exposure *. !game_exposure)) objet.proper_time;;


(*Fonction deplacant un objet instantanemment sans prendre en compte le temps de jeu*)
let deplac_objet_abso ref_objet velocity =
let objet = !ref_objet in
objet.position <- proj objet.position velocity 1.;
ref_objet := objet;;

(*Meme chose pour plusieurs objets*)
let rec deplac_objets_abso ref_objets velocity =
if ref_objets = [] then () else (
deplac_objet_abso (List.hd ref_objets) velocity;
deplac_objets_abso (List.tl ref_objets) velocity);;

(*Deplacement des etoiles en tenant compte de leur proximite*)
let deplac_star ref_star velocity =
  let star = !ref_star in
  star.last_pos <- star.pos;
  let (next_x, next_y) = addtuple star.pos (multuple velocity star.proximity) in
  star.pos <- modulo_reso (next_x, next_y);
  if (next_x > !phys_width || next_x < 0. || next_y > !phys_height || next_y < 0.) then star.last_pos <- star.pos;
(*On evite le motion blur incorrect cause par une teleportation d'un bord a l'autre de lecran.*)
  ref_star := star;;

(*Deplacement d'un ensemble detoiles*)
let rec deplac_stars ref_stars velocity =
  if ref_stars = [] then [] else (deplac_star (List.hd ref_stars) velocity) :: (deplac_stars (List.tl ref_stars) velocity);;


(*Fonction deplcant un objet selon une velocite donnee.
On tient compte du framerate et de la vitesse de jeu,
mais egalement du temps propre de l'objet et de l'observateur*)
let deplac_objet ref_objet (dx, dy) =
let objet = !ref_objet in
  (*Si l'objet est un projectile, il despawne une fois au bord de l'écran*)
  objet.position <- proj objet.position (dx, dy) ((!time_current_frame -. !time_last_frame) *. !game_speed *. !observer_proper_time /. objet.proper_time);

ref_objet := objet;;

(*Fonction accelerant un objet selon une acceleration donnee.
On tient compte du framerate et de la vitesse de jeu,
mais également du temps propre de l'objet et de l'observateur*)
let accel_objet ref_objet (ddx, ddy) =
  let objet = !ref_objet in
  objet.velocity <- proj objet.velocity (ddx, ddy) ((!time_current_frame -. !time_last_frame) *. !game_speed *. !observer_proper_time /. objet.proper_time);
ref_objet := objet;;

(*Fonction boostant un objet selon une acceleration donnee.*)
(*Utile pour le controle clavier par petites impulsions.*)
let boost_objet ref_objet boost =
  let objet = !ref_objet in objet.velocity <- (proj objet.velocity boost 1.);
ref_objet := objet;;

(*Fonction de rotation d'objet*)
let rotat_objet ref_objet rotation =
  let objet = !ref_objet in objet.orientation <- objet.orientation +. rotation *. ((!time_current_frame -. !time_last_frame) *. !game_speed *. !observer_proper_time /. objet.proper_time);
ref_objet := objet;;


let couple_objet ref_objet momentum =
  let objet = !ref_objet in
  objet.moment <- objet.moment +. momentum *. ((!time_current_frame -. !time_last_frame) *. !game_speed *. !observer_proper_time /. objet.proper_time);
ref_objet := objet;;

(*Fonction de rotation d'objet instantannee, avec rotation en radians.*)
let tourn_objet ref_objet rotation =
  let objet = !ref_objet in
  objet.orientation <- objet.orientation +. rotation;
ref_objet := objet;;

(*Fonction de rotation d'objet, avec rotation en radian*s⁻²*)
let couple_objet_boost ref_objet momentum =
  let objet = !ref_objet in
  objet.moment <- objet.moment +. momentum ;
ref_objet := objet;;

(*Fonction de calcul de changement de position inertiel d'un objet physique.*)
let inertie_objet ref_objet = deplac_objet ref_objet (!ref_objet).velocity;;

(*On calcule le changement de position inertiel de tous les objets en jeu*)
let inertie_objets ref_objets =
List.iter inertie_objet ref_objets ;;(*TODO laisser tomber cette fonction, lecrire direct telle-quelle dans la boucle de jeu.*)

(*On calcule l'inertie en rotation des objets*)
let moment_objet ref_objet = rotat_objet ref_objet (!ref_objet).moment;;

(*D'un groupe d'objets*)
let moment_objets ref_objets = List.iter moment_objet ref_objets;; (*TODO supprimer cette fonction et appeler direct telle-quelle dans la boucle principale.*)

let decay_smoke ref_smoke =
  let smoke = !ref_smoke in
  smoke.visuals.radius <- (exp_decay smoke.visuals.radius smoke_half_radius smoke.proper_time) -. smoke_radius_decay *. (!observer_proper_time *. !game_speed *. (!time_current_frame -. !time_last_frame) /. smoke.proper_time);
  (*Si l'exposition est deja minimale, ne pas encombrer par un calcul de decroissance expo supplementaire*)
  if smoke.hdr_exposure > 0.001 then  smoke.hdr_exposure <- (exp_decay smoke.hdr_exposure smoke_half_col smoke.proper_time);;

let decay_chunk ref_chunk =
  let chunk = !ref_chunk in
  chunk.visuals.radius <- chunk.visuals.radius -. (!observer_proper_time *. !game_speed *. chunk_radius_decay *. (!time_current_frame -. !time_last_frame) /. chunk.proper_time);;

let decay_chunk_explo ref_chunk =
  let chunk = !ref_chunk in
  chunk.visuals.radius <- chunk.visuals.radius -. (!observer_proper_time *. !game_speed *. chunk_explo_radius_decay *. (!time_current_frame -. !time_last_frame) /. chunk.proper_time);;

let damage ref_objet damage =
  let objet = !ref_objet in
  objet.health <- objet.health -. (max 0. (objet.dam_ratio *. damage -. objet.dam_res));
  game_screenshake := !game_screenshake +. damage *. screenshake_dam_ratio;
  if !variable_exposure then game_exposure := !game_exposure *. exposure_ratio_damage;
  if !flashes then add_color := hdr_add !add_color (intensify {r=1.;v=0.7;b=0.5} (damage *. flashes_damage));
  ref_objet := objet;;

let phys_damage ref_objet damage =
  let objet = !ref_objet in
  objet.health <- objet.health -. (max 0. (objet.phys_ratio *. damage -. objet.phys_res));
  game_screenshake := !game_screenshake +. damage *. screenshake_phys_ratio *. objet.mass /. screenshake_phys_mass;
  ref_objet := objet;;

let is_alive ref_objet = !ref_objet.health >= 0.
let is_dead ref_objet = !ref_objet.health < 0.;;

(*Fonction permettant de spawner un nombre de fragments d'asteroide*)
let rec spawn_n_frags ref_source ref_dest n =
   if n=0 then ref_dest
   else (spawn_n_frags ref_source ref_dest (n-1)) @ (List.map frag_asteroid (List.filter is_dead ref_source));;

(*Verifie si un objet depasse potentiellement dans lecran*)
let checkspawn_objet ref_objet_unspawned =
  let objet = !ref_objet_unspawned in
  let (x, y) = objet.position in
  let rad = objet.hitbox.ext_radius in
 (x -. rad < !phys_width) && (x +. rad > 0.) && (y -. rad < !phys_height) && (y +. rad > 0.)
let checknotspawn_objet ref_objet_unspawned = not (checkspawn_objet ref_objet_unspawned)
let close_enough ref_objet = hypothenuse (soustuple !ref_objet.position (!phys_width /. 2., !phys_height /. 2.)) < max_dist
let too_far ref_objet = not (close_enough ref_objet)
let close_enough_bullet ref_objet = hypothenuse !ref_objet.position < max_dist
let too_small ref_objet = !ref_objet.hitbox.ext_radius < asteroid_min_size
let big_enough ref_objet = not (too_small ref_objet)
let positive_radius ref_objet = !ref_objet.visuals.radius > 0.
let ischunk ref_objet = !ref_objet.hitbox.int_radius < chunk_max_size
let notchunk ref_objet = !ref_objet.hitbox.int_radius >= chunk_max_size

let rec filtertable ref_objets x y =
match ref_objets with
| [] -> []
| hd::tl ->
    let objet = !hd
    and (xmin, ymin) =
        soustuple
            (multuple_parallel
                (!phys_width, !phys_height)
                (3.*.x/.(float_of_int width_collision_table), 3.*.y/.(float_of_int height_collision_table)))
            (!phys_width, !phys_height) in
    let (xmax, ymax) = addtuple (xmin, ymin)
        (!phys_width*.3./.(float_of_int width_collision_table),
        !phys_height*.3./.(float_of_int height_collision_table))
    and (xobj,yobj) = objet.position
    and rad = objet.hitbox.ext_radius in
    if (xobj -. rad < xmax) && (xobj +. rad > xmin) && (yobj -. rad < ymax) && (yobj +. rad > ymin)
    then (hd :: (filtertable tl x y)) else (filtertable tl x y);;

let rec rev_filtertable ref_objets collision_table =
match ref_objets with
| [] -> ()
| hd::tl ->
    let objet = !hd in
    let (x1, y1) = (addtuple objet.position (!phys_width, !phys_height)) in
    let (x2, y2) = addtuple !current_jitter_coll_table
      ((float_of_int width_collision_table) *. x1 /. (3. *. !phys_width),
       (float_of_int height_collision_table) *. y1 /. (3. *. !phys_height)) in
    let (xint, yint) = ((int_of_float x2), (int_of_float y2)) in
    if (x2 < 0. ||y2 < 0.|| x2 >= (float_of_int width_collision_table) || y2 >= (float_of_int height_collision_table))
    then (
       (* print_endline("Object out of table : ");
      print_endline((string_of_float x2) ^ "/" ^ (string_of_int width_collision_table) ^ ", " ^ (string_of_float y2) ^ "/" ^ (string_of_int height_collision_table)); *)
    )else (
      let already_in_table = Array.get collision_table (xint*height_collision_table+yint) in
      Array.set collision_table (xint*height_collision_table+yint) (hd :: already_in_table);
      );
   rev_filtertable tl collision_table;;


let rec center_of_attention ref_objets pos =
  match ref_objets with
  | [] -> (0.,0.)
  | hd::tl ->
    let rel_pos = (soustuple (!hd).position pos) in
      addtuple (multuple (soustuple (!hd).position (!phys_width /. 2., !phys_height /. 2.)) ((!hd).mass /. (10. +. (distancecarre rel_pos (0.,0.)))))  (center_of_attention tl pos);;

(*Fonction despawnant les objets trop lointains et morts, ou avec rayon negatif*)
let despawn ref_etat =
    let etat = !ref_etat in

   List.iter decay_chunk_explo etat.ref_chunks_explo;
   if !chunks then (
   List.iter decay_chunk etat.ref_chunks;
   List.iter decay_chunk etat.ref_chunks_oos;

   etat.ref_chunks <- etat.ref_chunks @ (List.filter ischunk etat.ref_objets);
   etat.ref_chunks <- etat.ref_chunks @ (List.filter ischunk etat.ref_objets_oos);
   etat.ref_chunks <- etat.ref_chunks @ (List.filter ischunk etat.ref_toosmall);
   etat.ref_chunks <- etat.ref_chunks @ (List.filter ischunk etat.ref_toosmall_oos);
   etat.ref_chunks <- etat.ref_chunks @ (List.filter ischunk etat.ref_fragments);
   )else(etat.ref_chunks <- []);

   etat.ref_objets       <- List.filter is_alive etat.ref_objets;
   etat.ref_objets       <- List.filter notchunk etat.ref_objets;

   etat.ref_objets_oos   <- List.filter is_alive etat.ref_objets_oos;
   etat.ref_objets_oos   <- List.filter notchunk etat.ref_objets_oos;

   etat.ref_toosmall     <- List.filter is_alive etat.ref_toosmall;
   etat.ref_toosmall     <- List.filter notchunk etat.ref_toosmall;

   etat.ref_toosmall_oos <- List.filter is_alive etat.ref_toosmall_oos;
   etat.ref_toosmall_oos <- List.filter notchunk etat.ref_toosmall_oos;

   etat.ref_fragments    <- List.filter is_alive etat.ref_fragments;
   etat.ref_fragments    <- List.filter notchunk etat.ref_fragments;

   etat.ref_projectiles  <- List.filter is_alive etat.ref_projectiles;
   etat.ref_projectiles  <- List.filter close_enough_bullet etat.ref_projectiles;

   etat.ref_smoke        <- List.filter positive_radius  etat.ref_smoke;
   etat.ref_smoke_oos    <- List.filter positive_radius  etat.ref_smoke_oos;
   etat.ref_chunks       <- List.filter positive_radius  etat.ref_chunks;
   etat.ref_chunks_oos   <- List.filter positive_radius  etat.ref_chunks_oos;

   etat.ref_chunks_explo <- List.filter positive_radius  etat.ref_chunks_explo;

  ref_etat := etat;;

let recenter_objet ref_objet =
  let objet = !ref_objet in
  objet.position <- modulo_3reso objet.position;
ref_objet := objet;;

let collision_circles pos0 r0 pos1 r1 = distancecarre pos0 pos1 < carre (r0 +. r1);;
let collision_point pos_point pos_circle radius = distancecarre pos_point pos_circle < carre radius;;

let rec collisions_points pos_points pos_circle radius =
match pos_points with
|[] -> false
|hd::tl -> collision_point hd pos_circle radius || collisions_points tl pos_circle radius;;


let collision_poly pos poly rotat circle_pos radius =
  let pos_points = (depl_affine_poly (poly_to_affine poly rotat 1.) pos) in
  collisions_points pos_points circle_pos radius;;

let collision objet1 objet2 precis=
  nb_collision_checked := !nb_collision_checked +1;
(*Si on essaye de collisionner un objet avec lui-meme cela ne fonctionne pas*)
if objet1 = objet2 then false
  else (
  let hitbox1 = objet1.hitbox and hitbox2 = objet2.hitbox
  and pos1 = objet1.position and pos2 = objet2.position in
  if (not !advanced_hitbox && not precis) then
  collision_circles pos1 hitbox1.int_radius pos2 hitbox2.int_radius
  else
    if (collision_circles pos1 hitbox1.int_radius pos2 hitbox2.int_radius)
    then true
    else
    ( collision_poly pos1 hitbox1.points objet1.orientation pos2 hitbox2.int_radius)||(collision_poly pos2 hitbox2.points objet2.orientation pos1 hitbox1.int_radius));;

(*Verifie la collision entre un objet et une liste d'objets*)
let rec collision_objet_liste ref_objet ref_objets precis =
  match ref_objets with
  | [] -> false
  | _ -> collision !ref_objet !(List.hd ref_objets) precis || collision_objet_liste ref_objet (List.tl ref_objets) precis;;

(*S'applique seulement aux fragments -> on repousse selon la normale*)
(*Retourne les objets de la liste 1 etant en collision avec des objets de la liste 2*)
let rec collision_objets_listes ref_objets1 ref_objets2 precis =
  if ref_objets1 = [] || ref_objets2 = [] then []
  else if collision_objet_liste (List.hd ref_objets1) ref_objets2 precis
    then List.hd ref_objets1 :: collision_objets_listes (List.tl ref_objets1) ref_objets2 precis
    else collision_objets_listes (List.tl ref_objets1) ref_objets2 precis;;

(*Retourne les objets de la liste 1 netant PAS en collision avec des objets de la liste 2*)
let rec no_collision_objets_listes ref_objets1 ref_objets2 precis =
  if ref_objets1 = [] then [] else if ref_objets2 = [] then ref_objets1
  else if collision_objet_liste (List.hd ref_objets1) ref_objets2 precis
    then no_collision_objets_listes (List.tl ref_objets1) ref_objets2 precis
    else List.hd ref_objets1 :: no_collision_objets_listes (List.tl ref_objets1) ref_objets2 precis;;
    
(*Retourne tous les objets d'une liste etant en collision avec au moins un autre*)
let rec collisions_sein_liste ref_objets precis = collision_objets_listes ref_objets ref_objets precis;;

(*Retourne tous les objets au sein d'une liste netant pas en collision avec les autres*)
let rec no_collisions_liste ref_objets precis = no_collision_objets_listes ref_objets ref_objets precis;;

(*Fonction appelee en cas de collision de deux objets.
La fonction pourrait etre amelioree, avec une variable friction sur les objets,
et transfert entre moment et inertie.*)
let consequences_collision ref_objet1 ref_objet2 =
  match !ref_objet1.objet with
  | Explosion -> damage ref_objet2 !ref_objet1.mass (*On applique les dégats de l'explosion*)
  | Projectile -> damage ref_objet1 0.1 (*On endommage le projectile pour qu'il meure*)
  | _ ->  (*Si ce n'est ni une explosion ni un projectile, on calcule les effets de la collision physique*)
    let objet1 = !ref_objet1 and objet2 = !ref_objet2 in
    let total_mass = objet1.mass +. objet2.mass in
    let moy_velocity =
      moytuple
         (multuple objet1.velocity (1. /. objet1.proper_time))
         (multuple objet2.velocity (1. /. objet2.proper_time))
         (objet1.mass /. total_mass) in
    let (angle_obj1, dist1) = affine_to_polar (soustuple objet1.position objet2.position) in
    let (angle_obj2, dist2) = affine_to_polar (soustuple objet2.position objet1.position) in
    (*Stockage des ancienne vélocités, pour calculer les dégats en fonction du nombre de G encaissées*)

    let old_vel1 = objet1.velocity in
    let old_vel2 = objet2.velocity in

    let veloc_obj1 =
      multuple
       (addtuple moy_velocity (polar_to_affine angle_obj1 (total_mass /. objet1.mass)))
       objet1.proper_time in
    objet2.velocity <-
      multuple
         (addtuple moy_velocity (polar_to_affine angle_obj2 (total_mass /. (objet2.mass *. objet2.proper_time))))
         objet2.proper_time;
    objet1.velocity <- veloc_obj1;

    if not !pause then (
    let oldpos1 = objet1.position and oldpos2 = objet2.position in
    let oldvel1 = objet1.velocity and oldvel2 = objet2.velocity in
    let elapsed_time = !time_current_frame -. !time_last_frame in

    (*Pour éloigner les objets intriqués*)
    objet1.position <- addtuple oldpos1 (polar_to_affine angle_obj1 (min_repulsion *. elapsed_time));
    objet2.position <- addtuple oldpos2 (polar_to_affine angle_obj2 (min_repulsion *. elapsed_time));

    (*Pour éloigner les objets intriqués*)
    objet1.velocity <- addtuple oldvel1 (polar_to_affine angle_obj1 (min_bounce *. elapsed_time));
    objet2.velocity <- addtuple oldvel2 (polar_to_affine angle_obj2 (min_bounce *. elapsed_time));

    (*Changement de velocité subi par l'objet*)
    let g1 = hypothenuse (soustuple old_vel1 objet1.velocity) in
    let g2 = hypothenuse (soustuple old_vel2 objet2.velocity) in

    ref_objet1 := objet1;
    ref_objet2 := objet2;
    (*Les dégats physiques dépendent du changement de vitesse subie au carré.
    On applique un ratio pour réduire la valeur gigantesque générée*)
    phys_damage ref_objet1 (!ratio_phys_deg *. carre g1);
    phys_damage ref_objet2 (!ratio_phys_deg *. carre g2));;


let consequences_collision_frags ref_frag1 ref_frag2 =
  let frag1 = !ref_frag1 and frag2 = !ref_frag2 in
  let (angle_obj1, dist1) = affine_to_polar (soustuple frag1.position frag2.position) in
  let (angle_obj2, dist2) = affine_to_polar (soustuple frag2.position frag1.position) in
  let oldpos1 = frag1.position and oldpos2 = frag2.position in
  let oldvel1 = frag1.velocity and oldvel2 = frag2.velocity in
  let elapsed_time = !time_current_frame -. !time_last_frame in
    frag1.position <- addtuple oldpos1 (polar_to_affine angle_obj1 (elapsed_time *. fragment_min_repulsion));
    frag2.position <- addtuple oldpos2 (polar_to_affine angle_obj2 (elapsed_time *. fragment_min_repulsion));
    frag1.velocity <- addtuple oldvel1 (polar_to_affine angle_obj1 (elapsed_time *. fragment_min_bounce));
    frag2.velocity <- addtuple oldvel2 (polar_to_affine angle_obj2 (elapsed_time *. fragment_min_bounce));
  ref_frag1 := frag1;
  ref_frag2 := frag2

let rec calculate_collisions_fragvfrags ref_frag ref_frags =
  match ref_frags with
  | [] -> []
  | hd::tl -> if (collision !ref_frag !hd false)
      then (consequences_collision_frags ref_frag hd;ref_frag::[hd])
      else (calculate_collisions_fragvfrags ref_frag tl);;

let rec calculate_collisions_frags ref_frags =
  match ref_frags with
  | [] -> []
  | hd::tl ->
      let colliding = calculate_collisions_fragvfrags hd tl in
      colliding @ (calculate_collisions_frags (diff tl colliding));;

(*Fonction vérifiant la collision entre un objet et les autres objets
et appliquant les effets de collision*)
let rec calculate_collisions_objet ref_objet ref_objets precis =
if ref_objets = [] then () else (
  if collision !ref_objet !(List.hd ref_objets) precis then consequences_collision ref_objet (List.hd ref_objets);
  calculate_collisions_objet ref_objet (List.tl ref_objets) precis);;

let rec calculate_collisions_objets ref_objets =
if List.length ref_objets <= 1 then () else (
  calculate_collisions_objet (List.hd ref_objets) (List.tl ref_objets) true;
  calculate_collisions_objets (List.tl ref_objets));;

let rec calculate_collisions_listes_objets ref_objets1 ref_objets2 precis =
if ref_objets1 = [] || ref_objets2 = [] then () else (
  calculate_collisions_objet (List.hd ref_objets1) ref_objets2 precis;
  calculate_collisions_listes_objets (List.tl ref_objets1) ref_objets2 precis);;

let calculate_collision_tables tab1 tab2 extend =
   for x = 0 to width_collision_table-1 do
      for y = 0 to height_collision_table-1 do
         calculate_collisions_listes_objets (Array.get tab1 (x*height_collision_table+y)) (Array.get tab2 (x*height_collision_table+y)) true;
      done;
   done;

   if(extend)then(
      for x = 0 to width_collision_table-2 do
         for y = 0 to height_collision_table-2 do
            let base_xy = x*height_collision_table+y in
            let offset_x = height_collision_table and offset_y = 1 in
            calculate_collisions_listes_objets (Array.get tab1 base_xy) (Array.get tab2 (base_xy+offset_y)) false;
            calculate_collisions_listes_objets (Array.get tab1 base_xy) (Array.get tab2 (base_xy+offset_x)) false;
            calculate_collisions_listes_objets (Array.get tab1 base_xy) (Array.get tab2 (base_xy+offset_x+offset_y)) false;
         done;
      done;
   );;

(*Petite fonction de deplacement d'objet expres pour les modulos*)
(*Car la fonction de deplacement standard depend de Δt*)
let deplac_obj_modulo ref_objet (x,y) = (*x et y sont des entiers, en quantité d'écrans*)
  let objet = !ref_objet in
  objet.position <- addtuple objet.position (!phys_width *. float_of_int x, !phys_height *. float_of_int y);
  ref_objet := objet


(* --- initialisations etat --- *)

(* Affichage des états*)

(*Fonction d'affichage de barre de vie. Nécessite un quadrilatère comme polygone d'entrée.
Les deux premiers points correspondent à une valeur de zéro, et les deux derniers à la valeur max de la barre.
On peut mettre des quadrilatères totalement arbitraires*)
let affiche_barre ratio [point0;point1;point2;point3] color_bar =
  (*Cette fonction me prévient comme quoi je n'ai pas prévu le cas [].
  Cependant, je pense que c'est suffisamment clair qu'on impose un argument
  avec 4 tuplés. Du coup j'ignore purement et simplement cet avertissement.*)
  set_color color_bar;
  fill_poly (Array.of_list (relative_poly
  [point0;point1;
  (*Pour les deux points devant bouger selon le ratio,
  on fait simplement une moyenne pondérée.*)
  (moytuple point2 point1 ratio);
  (moytuple point3 point0 ratio)]));;


(*Fonction attribuant une forme à un caractère*)
let shape_char carac =
  match carac with
  |'0' -> [(0.25 ,0.);(0.75 ,0.);(1.   ,0.2);(1.   ,0.8);(0.75 , 1.);(0.25 ,1. );(0.  ,0.8 );(0.  ,0.2 );(0.25 ,0.2);(0.75 ,0.6);(0.75 ,0.8);(0.25,0.375);(0.25,0.8);(0.75,0.8);(0.75,0.2);(0.,0.2)]
  |'1' -> [(0.125,0.);(0.875,0.);(0.875,0.2);(0.625,0.2);(0.625,1. );(0.375,1. );(0.  ,0.75);(0.15,0.65);(0.375,0.8);(0.375,0.2);(0.125,0.2)]
  |'2' -> [(0.   ,0.);(1.   ,0.);(1.   ,0.2);(0.35 ,0.2);(1.   ,0.5);(1.   ,0.8);(0.75,1.  );(0.25,1.  );(0.   ,0.8);(0.   ,0.6);(0.25 ,0.6);(0.25,0.8  );(0.75,0.8);(0.75,0.6);(0.,0.2)]
  |'3' -> [(0.25 ,0.);(0.75 ,0.);(1.   ,0.2);(1.   ,0.4);(0.875,0.5);(1.   ,0.6);(1.  ,0.8 );(0.75,1.  );(0.25 ,1. );(0.   ,0.8);(0.   ,0.6);(0.25,0.6  );(0.25,0.8);(0.75,0.8);(0.75,0.6);(0.5,0.6);(0.5,0.4);(0.75,0.4);(0.75,0.2);(0.25,0.2);(0.25,0.4);(0.,0.4);(0.,0.2)]
  |'4' -> [(0.5  ,0.);(0.75 ,0.);(0.75 ,1. );(0.5  ,1. );(0.   ,0.4);(0.   ,0.2);(1.  ,0.2 );(1.  ,0.4 );(0.25 ,0.4);(0.5  ,0.8)]
  |'5' -> [(0.25 ,0.);(0.75 ,0.);(1.   ,0.2);(1.   ,0.5);(0.25 ,0.7);(0.25 ,0.8);(1.  ,0.8 );(1.  ,1.  );(0.   ,1. );(0.   ,0.6);(0.75 ,0.4);(0.75,0.2  );(0.25,0.2);(0.25,0.35);(0.,0.4);(0.,0.2);(0.25,0.)]
  |'6' -> [(0.25 ,0.);(0.75 ,0.);(1.   ,0.2);(1.   ,0.4);(0.75 ,0.6);(0.25 ,0.6);(0.25,0.8 );(1.  ,0.8 );(0.75 ,1. );(0.25 ,1. );(0.   ,0.8);(0.  ,0.4  );(0.75,0.4);(0.75,0.2);(0.25,0.2);(0.25,0.4);(0.,0.4);(0.,0.2)]
  |'7' -> [(0.25 ,0.);(0.5  ,0.);(1.   ,0.8);(1.   ,1. );(0.   ,1. );(0.   ,0.8);(0.75,0.8 )]
  |'8' -> [(0.25 ,0.);(0.75 ,0.);(1.   ,0.2);(1.   ,0.4);(0.875,0.5);(1.   ,0.6);(1.  ,0.8 );(0.75,1.  );(0.25 ,1. );(0.25 ,0.8);(0.75 ,0.8);(0.75,0.6  );(0.25,0.6);(0.25,0.4);(0.75,0.4);(0.75,0.2);(0.25,0.2);(0.25,1.);(0.,0.8);(0.,0.6);(0.125,0.5);(0.,0.4);(0.,0.2)]
  |'9' -> [(0.75 ,1.);(0.25 ,1.);(0.   ,0.8);(0.   ,0.6);(0.25 ,0.4);(0.75 ,0.4);(0.75,0.2 );(0.  ,0.2 );(0.25 ,0. );(0.75 ,0. );(1.   ,0.2);(1.  ,0.6  );(0.25,0.6);(0.25,0.8);(0.75,0.8);(0.75,0.6);(1.,0.6);(1.,0.8)]
  |' ' -> [(0.,0.);(0.,0.);(0.,0.)]
  |'A' -> [(0.   ,0.);(0.25 ,0.);(0.25 ,0.4);(0.75 ,0.4);(0.75 ,0.4);(0.75 ,0.6);(0.25,0.6 );(0.25,0.8 );(0.75 ,0.8);(0.75 ,0. );(1.   ,0. );(1.  ,0.8  );(0.75,1. );(0.25,1. );(0.,0.8)]
  |'B' -> [(0.   ,0.);(0.75 ,0.);(1.   ,0.2);(1.   ,0.4);(0.875,0.5);(1.   ,0.6);(1.  ,0.8 );(0.75,1.  );(0.25 ,1. );(0.25 ,0.8);(0.75 ,0.8);(0.75,0.6  );(0.25,0.6);(0.25,0.4);(0.75,0.4);(0.75,0.2);(0.25,0.2);(0.,1.)]
  |'C' -> [(0.25 ,0.);(0.75 ,0.);(1.   ,0.2);(1.   ,0.4);(0.75 ,0.4);(0.75 ,0.2);(0.25,0.2 );(0.25 ,0.8);(0.75 ,0.8);(0.75 ,0.6);(1.   ,0.6);(1.   ,0.8);(0.75,1.   );(0.25,1. );(0.  ,0.8);(0.  ,0.2)]
  |'D' -> [(0.   ,0.);(0.75 ,0.);(1.   ,0.2);(1.   ,0.8);(0.75 ,1. );(0.   ,1. );(0.   ,0.2);(0.25 ,0.2);(0.25 ,0.8);(0.75,0.8);(0.75,0.2);(0.,0.2)]
  |'E' -> [(0.   ,0.);(0.75 ,0.);(1.   ,0.2);(0.25 ,0.2);(0.25 ,0.4);(0.5  ,0.4);(0.5 ,0.6 );(0.25 ,0.6);(0.25 ,0.8);(1.   ,0.8);(0.75 ,1. );(0.   ,1. )]
  |'F' -> [(0.   ,0.);(0.25 ,0.);(0.25 ,0.4);(0.5  ,0.4);(0.75 ,0.6);(0.25 ,0.6);(0.25,0.8 );(1.   ,0.8);(1.   ,1. );(0.   ,1. );]
  |'G' -> [(0.25 ,0.);(0.75 ,0.);(1.   ,0.2);(1.   ,0.6);(0.5  ,0.6);(0.5  ,0.4);(0.75,0.4 );(0.75 ,0.2);(0.25 ,0.2);(0.25 ,0.8);(1.   ,0.8);(0.75,1.   );(0.25,1. );(0.  ,0.8);(0.  ,0.2)]
  |'I' -> [(0.125,0.);(0.875,0.);(0.875,0.2);(0.625,0.2);(0.625,0.8);(0.875,0.8);(0.875,1. );(0.125,1. );(0.125,0.8);(0.375,0.8);(0.375,0.2);(0.125,0.2)]
  |'O' -> [(0.25 ,0.);(0.75 ,0.);(1.   ,0.2);(1.   ,0.8);(0.75 ,1. );(0.25 ,1. );(0.  ,0.8 );(0.   ,0.2);(0.25 ,0.2);(0.25 ,0.8);(0.75,0.8);(0.75,0.2);(0.,0.2)]
  |'R' -> [(0.   ,0.);(0.25 ,0.);(0.25 ,0.8);(0.75 ,0.8);(0.75 ,0.6);(0.25 ,0.6);(0.25,0.4 );(0.75 ,0. );(1.   ,0. );(0.5  ,0.4);(0.75,0.4);(1.  ,0.6);(1.,0.8);(0.75,1.);(0.,1.)]
  |'S' -> [(0.25 ,0.);(0.75 ,0.);(1.   ,0.2);(1.   ,0.4);(0.75 ,0.6);(0.25 ,0.6);(0.25,0.8 );(1.   ,0.8);(0.75 ,1. );(0.25 ,1. );(0.   ,0.8);(0.  ,0.6  );(0.25,0.4);(0.75,0.4);(0.75,0.2);(0. ,0.2)]
  |'T' -> [(0.385,0.);(0.625,0.);(0.625,0.8);(1.   ,0.8);(1.   ,1. );(0.   ,1. );(0.  ,0.8 );(0.385,0.8)]
  |'W' -> [(0.   ,1.);(0.2  ,0.);(0.4  ,0. );(0.5  ,0.2);(0.6  ,0. );(0.8  ,0. );(1.  ,1.  );(0.6  ,0.4);(0.6  ,0.6);(0.4  ,0.6);(0.4  ,0.4);(0.2 ,1.   )]
  | _  -> [(0.   ,0.);(1.   ,0.);(1.   ,1. );(0.   ,1. )];;

(*Fonction prenant 4 points d'encadrement, et un point relatif, et le rendant transformé*)
let displacement [point0;point1;point2;point3] (relx,rely) = multuple (moytuple (moytuple point2 point1 rely) (moytuple point3 point0 rely) relx) !ratio_rendu;;

(*Fonction prenant 4 points et un poly incrit dans ces 4 points, et rendant les coordonées du poly qui en découle.*)
let rec displace_shape encadrement shape =
match shape with
| [] -> []
| hd::tl -> (inttuple (displacement encadrement hd) :: displace_shape encadrement tl);;

let render_char encadrement charac = fill_poly (Array.of_list (displace_shape encadrement (shape_char charac)));;

let rec render_characs str (x0, y0) l_char h_char l_space shake =
  match str with
  | [] -> ()
  | hd::tl -> (
    render_char [(x0 +. (randfloat ~-.shake shake),           y0 +. (randfloat ~-.shake shake));
                 (x0 +. (randfloat ~-.shake shake) +. l_char, y0 +. (randfloat ~-.shake shake));
                 (x0 +. (randfloat ~-.shake shake) +. l_char, y0 +. (randfloat ~-.shake shake) +. h_char);
                 (x0 +. (randfloat ~-.shake shake),           y0 +. (randfloat ~-.shake shake) +. h_char)] hd;
    render_characs tl (x0 +. l_char +. l_space, y0) l_char h_char l_space shake
    );;

(*Fonction trouvée sur stackoverflow pour pouvoir transformer une string en liste de charactères*)
let rec list_car charac = match charac with
    | "" -> []
    | ch -> (String.get ch 0 ) :: (list_car (String.sub ch 1 ( (String.length ch)-1) ) )  ;;

let render_string str pos l_char h_char l_space shake= (render_characs (list_car str) pos l_char h_char l_space shake);;


(*L'effet de scanlines a pour but d'imiter les anciens écrans CRT,
qui projetaient l'image ligne par ligne.*)
let rec render_scanlines nb=
  set_color black;
  if nb < height then (
  moveto 0 nb;
  lineto width nb;
  render_scanlines (nb + scanlines_period));;

(*Rendu de cœur*)
let draw_heart (x0,y0) (x1,y1) =
  let (x0,y0) = multuple (x0,y0) !ratio_rendu and (x1,y1) = multuple (x1,y1) !ratio_rendu in
  set_color red;
  let quartx = (x1 -. x0)/. 4. and tiery = (y1 -. y0) /. 3. in
  fill_ellipse (int_of_float (x0 +. quartx +. 0.5)) (int_of_float (y1 -. tiery)) (int_of_float (quartx +. 0.5)) (int_of_float (tiery +. 0.5));
  fill_ellipse (int_of_float (x1 -. quartx +. 0.5)) (int_of_float (y1 -. tiery)) (int_of_float (quartx +. 0.5)) (int_of_float (tiery +. 0.5));
  let decal = 1. -. (1. /. (sqrt 2.)) in
  fill_poly (Array.of_list
    [(inttuple (x0 +. 2. *. quartx, y0));
     (inttuple (x0 +. (decal *. quartx +. 0.5), y0 +. ((1. +. decal) *. tiery)));
     (inttuple (x0 +. 2. *. quartx, y1 -. tiery ));
     (inttuple (x1 -. (decal *. quartx +. 0.5), y0 +. ((1. +. decal) *. tiery)))]);;

let rec draw_n_hearts lastx n =
  if n > 0 then (
  set_line_width 2;
  draw_heart (lastx -. 0.03 *. !phys_width, 0.75 *. !phys_height) (lastx, 0.80 *. !phys_height);
  draw_n_hearts (lastx -. 0.05  *. !phys_width) (n-1));;

let affiche_etat ref_etat =
   let temptime = Unix.gettimeofday() in
   let etat = !ref_etat in
   (*On actualise la caméra en fonction du vaisseau.
   Dans les faits on bouge les objets, mais tous de la même valeur donc pas de réel impact*)
    (*On calcule les déplacements de la caméra pour le rendu de caméra dynamique*)
    let ship = !(etat.ref_ship) in
    let (next_x, next_y) =
      addtuple (polar_to_affine ship.orientation (!phys_width *. camera_ratio_vision))
      (if !pause then ship.position else(
      addtuple
        (addtuple ship.position (multuple ship.velocity (camera_prediction)))
        (multuple (center_of_attention (etat.ref_objets @ etat.ref_objets_oos) ship.position)
          camera_ratio_objects))) in
  let elapsed_time = !game_speed *. (!time_last_frame -. !time_current_frame) in

  let move_camera =
    (((!phys_width /. 2.) -. next_x) -. (abso_exp_decay ((!phys_width /. 2.) -. next_x) camera_half_depl),
   ((!phys_height/. 2.) -. next_y) -. (abso_exp_decay ((!phys_height/. 2.) -. next_y) camera_half_depl)) in

  let (movex, movey) = move_camera in
  let (x, y) = ship.position in

   let move_camera = (
  (if x +. movex < camera_start_bound *. !phys_width
   then movex -. camera_max_force *. elapsed_time *. ( ~-. x -. movex +. camera_start_bound *. !phys_width)
   else if x +. movex > (1. -. camera_start_bound) *. !phys_width
      then movex -. camera_max_force *. elapsed_time *. ( ~-. x -. movex +. (1. -. camera_start_bound) *. !phys_width)
      else movex),
   (if y +. movey < camera_start_bound *. !phys_height
      then movey -. camera_max_force *. elapsed_time *. ( ~-. y -. movey +. camera_start_bound *. !phys_height)
      else if y +. movey > (1. -. camera_start_bound) *. !phys_height
      then movey -. camera_max_force *. elapsed_time *. ( ~-. y -. movey +. (1. -. camera_start_bound) *. !phys_height)
      else movey)) in

   ignore (deplac_stars etat.ref_stars      move_camera);
   deplac_objet_abso  etat.ref_ship         move_camera;
   deplac_objets_abso etat.ref_objets       move_camera;
   deplac_objets_abso etat.ref_objets_oos   move_camera;
   deplac_objets_abso etat.ref_toosmall     move_camera;
   deplac_objets_abso etat.ref_toosmall_oos move_camera;
   deplac_objets_abso etat.ref_fragments    move_camera;
   deplac_objets_abso etat.ref_chunks       move_camera;
   deplac_objets_abso etat.ref_chunks_oos   move_camera;
   deplac_objets_abso etat.ref_chunks_explo move_camera;
   deplac_objets_abso etat.ref_projectiles  move_camera;
   deplac_objets_abso etat.ref_explosions   move_camera;
   deplac_objets_abso etat.ref_smoke        move_camera;
   deplac_objets_abso etat.ref_smoke_oos    move_camera;

   print_endline("prep_affich : " ^ string_of_float (1000. *. (Unix.gettimeofday()-.temptime)) ^ " ms");

  (*Fond d'espace*)
  if !retro then set_color black else set_color (rgb_of_hdr (intensify !space_color !game_exposure));
  fill_rect 0 ~-1 width height;

  if not !retro then (set_line_width 2; List.iter render_star_trail etat.ref_stars);(*Avec ou sans motion blur, on rend les étoiles comme il faut*)
  set_line_width 0;

  List.iter render_objet etat.ref_smoke;
  List.iter render_chunk etat.ref_chunks;
  List.iter render_projectile etat.ref_projectiles;
  render_objet etat.ref_ship;
  List.iter render_objet etat.ref_fragments;
  List.iter render_objet etat.ref_toosmall;
  List.iter render_objet etat.ref_objets;
  List.iter render_objet etat.ref_explosions;
  synchronize ();;


(********************************************************************************************************************)
(*Main updates*)
(********************************************************************************************************************)
(* calcul de l'etat suivant, apres un pas de temps *)
let etat_suivant ref_etat =
  even_frame := not !even_frame;
  if !even_frame then evener_frame := not !evener_frame;
  nb_collision_checked := 0;
  if !quit then (print_endline "Bye bye!"; exit 0);
  if !restart then (
    ref_etat := init_etat ();
    game_exposure := 0.;
    restart := false;
    pause := false
  );
  let etat = !ref_etat in
  if !pause then (
    game_speed_target := game_speed_target_pause;
    game_speed := game_speed_target_pause
  );
      stars_nb := stars_nb_default;
      projectile_number := projectile_number_default;

  if !stars_nb != !stars_nb_previous then (etat.ref_stars <- n_stars !stars_nb; stars_nb_previous := !stars_nb);

  (*On calcule le changement de vitesse naturel du jeu. Basé sur le temps réel et non le temps ingame pour éviter les casi-freeze*)
  game_speed := !game_speed_target +. abso_exp_decay (!game_speed -. !game_speed_target) half_speed_change;


  (*On calcule le jitter, pour l'appliquer de manière uniforme sur tous les objets et tous les rayons.*)
  current_jitter_double := (Random.float dither_power, Random.float dither_power);
  current_jitter_coll_table := soustuple (Random.float 1., Random.float 1.) (0.5,0.5);

  if not !pause then (
    (*On calcule la puissance du screenshake. Basé sur le temps en jeu. (Sauf si le jeu est en pause, auquel cas on actualise plus)*)
    game_screenshake := abso_exp_decay !game_screenshake screenshake_half_life;
    (*On calcule l'emplacement caméra pour le screenshake,
    en mémorisant l'emplacement précédent du screenshake (Pour le rendu correct des trainées de lumière et du flou)*)
    game_screenshake_previous_pos := !game_screenshake_pos;
    if !screenshake then game_screenshake_pos := multuple ((Random.float 2.) -. 1., (Random.float 2.) -. 1.) !game_screenshake;
    (*Dans le cas du lissage de screenshake, on fait une moyenne entre le précédent et l'actuel, pour un lissage du mouvement*)
    if screenshake_smooth then game_screenshake_pos := moytuple !game_screenshake_previous_pos !game_screenshake_pos screenshake_smoothness;
    game_exposure := !game_exposure_target +. abso_exp_decay (!game_exposure -. !game_exposure_target) exposure_half_life;
    add_color := intensify !add_color (abso_exp_decay 1. flashes_half_life);

    if !dyn_color then (
    (*On calcule le changement de filtre du jeu. Basé sur le temps en jeu *)
    mul_color := half_color !mul_color !mul_base filter_half_life;
    (*Idem pour l'espace*)
    space_color := half_color !space_color !space_color_goal space_half_life;
    (*Idem pour l'espace*)
    star_color := half_color !star_color !star_color_goal space_half_life
    )
  );

  (*On calcule tous les déplacements naturels dus à l'inertie des objets*)
  time_last_frame := !time_current_frame;
  time_current_frame := Unix.gettimeofday ();

  observer_proper_time := !(etat.ref_ship).proper_time;

  inertie_objet etat.ref_ship;
  inertie_objets etat.ref_objets;
  inertie_objets etat.ref_objets_oos;
  inertie_objets etat.ref_toosmall;
  inertie_objets etat.ref_toosmall_oos;
  inertie_objets etat.ref_fragments;
  inertie_objets etat.ref_chunks;
  inertie_objets etat.ref_chunks_explo;
  inertie_objets etat.ref_projectiles;
  inertie_objets etat.ref_smoke;

  moment_objet etat.ref_ship;
  moment_objets etat.ref_objets;
  moment_objets etat.ref_objets_oos;
  moment_objets etat.ref_toosmall;
  moment_objets etat.ref_toosmall_oos;
  moment_objets etat.ref_fragments;
  (*Inutile de calculer le moment des projectiles, explosions ou fumée, comme leur rotation n'a aucune importance*)

   let temptime = Unix.gettimeofday() in

   etat.ref_toosmall <- (List.filter too_small etat.ref_objets) @ etat.ref_toosmall;
   etat.ref_objets <- (List.filter big_enough etat.ref_objets);

   etat.ref_toosmall <- (List.filter too_small etat.ref_fragments) @ etat.ref_toosmall;
   etat.ref_fragments <- (List.filter big_enough etat.ref_fragments);

   let togoout_small = List.filter checknotspawn_objet etat.ref_toosmall in
   etat.ref_toosmall <- List.filter checkspawn_objet (etat.ref_toosmall_oos @ etat.ref_toosmall);
   etat.ref_toosmall_oos <- (List.filter checknotspawn_objet (etat.ref_toosmall_oos @ togoout_small));

   let togoout = List.filter checknotspawn_objet etat.ref_objets in
   etat.ref_objets <- List.filter checkspawn_objet (etat.ref_objets_oos @ etat.ref_objets);
   etat.ref_objets_oos <- (List.filter checknotspawn_objet etat.ref_objets_oos) @ togoout;
   print_endline("transferts :  " ^ string_of_float (1000. *. (Unix.gettimeofday()-.temptime)) ^ " ms");
   let temptime = Unix.gettimeofday() in
   let togoout_chunks =   List.filter checknotspawn_objet etat.ref_chunks in
   etat.ref_chunks     <- List.filter checkspawn_objet   (etat.ref_chunks @ etat.ref_chunks_oos);
   etat.ref_chunks_oos <-(List.filter checknotspawn_objet etat.ref_chunks_oos) @ togoout_chunks ;

   let togoout_smoke =   List.filter checknotspawn_objet etat.ref_smoke in
   etat.ref_smoke     <- List.filter checkspawn_objet   (etat.ref_smoke @ etat.ref_smoke_oos);
   etat.ref_smoke_oos <-(List.filter checknotspawn_objet etat.ref_smoke_oos) @ togoout_smoke ;

if not !pause then (
   let temptime = Unix.gettimeofday() in
   let objets_ref   = etat.ref_objets @ etat.ref_objets_oos
   and toosmall_ref = etat.ref_toosmall @ etat.ref_toosmall_oos
   and other_ref = etat.ref_ship :: etat.ref_explosions @ etat.ref_projectiles
   in
   for i=0 to height_collision_table*width_collision_table -1 do
      Array.set collision_table i [];
      Array.set collision_table_toosmall i [];
      Array.set collision_table_other i [];
      Array.set collision_table_frag i [];
   done;

   rev_filtertable objets_ref   collision_table;
   rev_filtertable toosmall_ref collision_table_toosmall;
   rev_filtertable other_ref    collision_table_other;
   rev_filtertable etat.ref_fragments collision_table_frag;

   let temptime = Unix.gettimeofday() in
   calculate_collision_tables collision_table collision_table true;
   calculate_collision_tables collision_table collision_table_toosmall false;
   (* calculate_collision_tables collision_table collision_table_frag true; *)
   calculate_collision_tables collision_table_other collision_table true;
   (* calculate_collision_tables collision_table_other collision_table_frag true; *)
   calculate_collision_tables collision_table_other collision_table_toosmall true;
   calculate_collision_tables collision_table_other collision_table_frag true;

   (*On fait apparaitre les fragments des astéroïdes détruits*)
   etat.ref_fragments <- spawn_n_frags etat.ref_objets etat.ref_fragments fragment_number;
   (*On fait apparaitre les fragments des toosmall. Ils vont direct dans toosmall, pas d'inter-collisions*)
   etat.ref_fragments <- spawn_n_frags etat.ref_toosmall etat.ref_fragments fragment_number;
   (*Pareil pour les fragments déjà cassés*)
   etat.ref_fragments <- spawn_n_frags etat.ref_fragments etat.ref_fragments fragment_number;

   (*On ralentit le temps selon le nombre d'asteroide detruits*)
   let nb_destroyed =
     List.length (List.filter is_dead etat.ref_objets)
   + List.length (List.filter is_dead etat.ref_objets_oos)
   + List.length (List.filter is_dead etat.ref_toosmall)
   + List.length (List.filter is_dead etat.ref_toosmall_oos)
   + List.length (List.filter is_dead etat.ref_fragments)
   in
   game_speed := !game_speed *. ratio_time_destr_asteroid ** (float_of_int nb_destroyed);
   etat.score <- etat.score + nb_destroyed;
   shake_score := (abso_exp_decay !shake_score shake_score_half_life) +. shake_score_ratio *. (float_of_int nb_destroyed);

   if !chunks then etat.ref_chunks <- (etat.ref_chunks @ (List.filter ischunk etat.ref_fragments));
   etat.ref_fragments <- (List.filter notchunk etat.ref_fragments); (*Éviter de détruire les perfs avec des fragments minuscules*)


   List.iter decay_smoke etat.ref_smoke_oos;
   List.iter decay_smoke etat.ref_smoke;
   if !smoke then etat.ref_smoke <- etat.ref_smoke @ etat.ref_explosions else etat.ref_smoke <- [];
   (* On vire les explosions précédentes *)
   etat.ref_explosions <- List.map spawn_explosion (List.filter is_dead etat.ref_projectiles);
   etat.ref_smoke <- etat.ref_smoke @ (List.map spawn_explosion_object (List.filter is_dead etat.ref_objets));
   etat.ref_smoke <- etat.ref_smoke @ (List.map spawn_explosion_object (List.filter is_dead etat.ref_toosmall));
   etat.ref_smoke <- etat.ref_smoke @ (List.map spawn_explosion_object (List.filter is_dead etat.ref_fragments));
   ref_etat := etat;


   if (is_dead etat.ref_ship) && not !pause
   then (etat.ref_explosions <- (spawn_explosion_death etat.ref_ship ((!time_current_frame -. !time_last_frame) *. !game_speed) :: etat.ref_explosions));

   if not !pause then etat.ref_explosions <- etat.ref_explosions @ (List.map spawn_explosion_chunk etat.ref_chunks_explo);

);

  if !smoke then(
    etat.ref_smoke <- etat.ref_smoke @ (List.map spawn_explosion_object (List.filter is_dead etat.ref_fragments)));

  (*On ralentit le temps selon le nombre d'explosions*)
  game_speed := !game_speed *. ratio_time_explosion ** (float_of_int (List.length etat.ref_explosions));

  if not !pause then (
   let temptime = Unix.gettimeofday() in
   (*On repousse et éloigne les fragments les uns des autres*)
   let tokeep = calculate_collisions_frags etat.ref_fragments in
   etat.ref_objets <- etat.ref_objets @ (diff etat.ref_fragments tokeep);
   etat.ref_fragments <- tokeep;
   print_endline("fragments :   " ^ string_of_float (1000. *. (Unix.gettimeofday()-.temptime)) ^ " ms");

  if !time_since_last_spawn > time_spawn_asteroid then (
    time_since_last_spawn := 0.;
    let nb_asteroids_stage = asteroid_min_nb + asteroid_stage_nb * etat.stage in
    if !current_stage_asteroids >= nb_asteroids_stage
    then (
      etat.stage <- etat.stage + 1;
      current_stage_asteroids := 0;
      let new_col = {
    r = randfloat rand_min_lum rand_max_lum ;
    v = randfloat rand_min_lum rand_max_lum ;
    b = randfloat rand_min_lum rand_max_lum } in
      mul_base := saturate new_col filter_saturation;
      space_color_goal := saturate (intensify new_col 10.) space_saturation;
      star_color_goal := saturate (intensify new_col 100.) star_saturation );

    etat.ref_objets_oos <- (ref (spawn_random_asteroid etat.stage)) :: etat.ref_objets_oos;
    current_stage_asteroids := !current_stage_asteroids + 1
  );
  time_since_last_spawn := !time_since_last_spawn +. (!time_current_frame -. !time_last_frame) *. !game_speed;

   List.iter recenter_objet etat.ref_objets;
   List.iter recenter_objet etat.ref_toosmall;
   List.iter recenter_objet etat.ref_objets_oos;
   List.iter recenter_objet etat.ref_toosmall_oos;
   List.iter recenter_objet etat.ref_fragments;

  (*On ne recentre pas les projectiles car ils doivent despawner une fois sortis de l'espace de jeu*)

  let elapsed_time = !time_current_frame -. !time_last_frame in
  (*On diminue le cooldown en fonction du temps passé depuis la dernière frame.*)
  (*On laisse si le cooldown est négatif, cela veut dire qu'un projectile a été tiré trop tard,
  et ce sera compensé par un projectile tiré trop tot, afin d'équilibrer.*)
  if etat.cooldown > 0. then etat.cooldown <- etat.cooldown -. !game_speed *. elapsed_time;
  if etat.cooldown_tp > 0. then etat.cooldown_tp <- etat.cooldown_tp -. !game_speed *. elapsed_time;
  ref_etat := etat;
  if autoregen then let ship = !(etat.ref_ship) in
  if ship.health <= ship_max_health && ship.health > 0. then
  ship.health <- ship.health +. elapsed_time *. autoregen_health;
  if ship.health > ship_max_health then ship.health <- ship_max_health;
  etat.ref_ship := ship;
  (*Suppression des objets qu'il faut*)
  despawn ref_etat;
  );
  let temptime = Unix.gettimeofday() in
  affiche_etat ref_etat;
  print_endline("time affich : " ^ string_of_float (1000. *. (Unix.gettimeofday()-.temptime)) ^ " ms");
  print_endline("")

(* acceleration du vaisseau *)
let acceleration ref_etat =
  let etat = !ref_etat in
  let orientation = !(etat.ref_ship).orientation in
  accel_objet etat.ref_ship (polar_to_affine orientation ship_max_accel);
  (*Feu à l'arrière du vaisseau. Spawne à chaque frame
  plus de frames = plus de particules, pertes de perf = moins de particules.*)
   if !(etat.ref_ship).health > 0. then (
   if !smoke then etat.ref_smoke <- etat.ref_smoke @ [spawn_fire etat.ref_ship]);
ref_etat:=etat;
etat_suivant ref_etat;;

(* boost du vaisseau, pour controle clavier *)
let boost ref_etat =
  let etat = !ref_etat in
  let orientation = !(etat.ref_ship).orientation in
  (*Dans le cas d'un controle de la vélocité et non de la position.*)
  (*C'est à dire en respectant le TP, et c'est bien mieux en terme d'expérience de jeu :) *)
  boost_objet etat.ref_ship (polar_to_affine orientation ship_max_boost);
(*Feu à l'arrière du vaisseau. Spawne spawn plusieurs particules à la fois pour le boost*)
let list_fire1 = [spawn_fire etat.ref_ship;spawn_fire etat.ref_ship;spawn_fire etat.ref_ship] in
let list_fire2 = [spawn_fire etat.ref_ship;spawn_fire etat.ref_ship;spawn_fire etat.ref_ship] in
let list_fire3 = [spawn_fire etat.ref_ship;spawn_fire etat.ref_ship;spawn_fire etat.ref_ship] in
etat.ref_smoke <- etat.ref_smoke @ list_fire1 @ list_fire2 @ list_fire3;
ref_etat:=etat;
etat_suivant ref_etat;;


(* rotation vers la gauche et vers la droite du ship *)
let rotation_gauche ref_etat =
if !ship_direct_rotat then
  rotat_objet !ref_etat.ref_ship ship_max_tourn
else(*Dans le cas d'un controle de la du couple et non de la rotation. Non recommandé de manière générale*)
  couple_objet !ref_etat.ref_ship ship_max_tourn;
etat_suivant ref_etat;;

let rotation_droite ref_etat =
if !ship_direct_rotat then
  rotat_objet !ref_etat.ref_ship (0. -. ship_max_tourn)
else(*Dans le cas d'un controle de la du couple et non de la rotation. Non recommandé de manière générale*)
  couple_objet !ref_etat.ref_ship (0. -. ship_max_tourn);
etat_suivant ref_etat;;


(* rotation vers la gauche et vers la droite du ship *)
let boost_gauche ref_etat =
if !ship_direct_rotat then
  tourn_objet !ref_etat.ref_ship (0. +. ship_max_rotat)
else(*Dans le cas d'un controle de la du couple et non de la rotation. Non recommandé de manière générale*)
  couple_objet_boost !ref_etat.ref_ship ship_max_tourn_boost;
etat_suivant ref_etat;;

let boost_droite ref_etat =
if !ship_direct_rotat then
  tourn_objet !ref_etat.ref_ship (0. -. ship_max_rotat)
else(*Dans le cas d'un controle de la du couple et non de la rotation. Non recommandé de manière générale*)
  couple_objet_boost !ref_etat.ref_ship (0. -. ship_max_tourn_boost);
etat_suivant ref_etat;;


(* Boost de cote, pour un meilleur controle clavier *)
let strafe_left ref_etat =
  let etat = !ref_etat in
  let orientation = !(etat.ref_ship).orientation +. (pi /. 2.) in
  boost_objet etat.ref_ship (polar_to_affine orientation ship_max_boost);
ref_etat:=etat;
etat_suivant ref_etat;;

let strafe_right ref_etat =
  let etat = !ref_etat in
  let orientation = !(etat.ref_ship).orientation -. (pi /. 2.) in
  boost_objet etat.ref_ship (polar_to_affine orientation ship_max_boost);
ref_etat:=etat;
etat_suivant ref_etat

(* tir d'un nouveau projectile *)
let tir ref_etat =
(*Tant que le cooldown est superieur a 0, on ne tire pas.*)
(*Sauf si le temps que la prochaine frame arrive justifie qu'on puisse tirer entre temps*)
(*Plus le cooldown est faible, plus le tir devrait arriver tot*)
(*Donc on laisse le hasard decider si le tir spawn maintenant ou a la frame suivante.*)
(*On considere que le temps de la prochaine frame sera celui de la derniere,
ce qui est une approximation generalement correcte*)
  let etat = !ref_etat in
  let ship = !(etat.ref_ship) in
  while etat.cooldown <= 0.
  do
    if !flashes then add_color := hdr_add !add_color (intensify {r=100.;v=50.;b=25.} flashes_tir);
    if !variable_exposure then game_exposure := !game_exposure *. exposure_tir;
    game_screenshake := !game_screenshake +. screenshake_tir_ratio;
    (*On ajoute les projectiles *)
    etat.ref_projectiles <- (spawn_n_projectiles ship !projectile_number) @ etat.ref_projectiles;
    (*Ajout du muzzleflash correspondant aux tirs*)
    if !smoke then etat.ref_smoke <- etat.ref_smoke @ (List.map spawn_muzzle (spawn_n_projectiles ship !projectile_number));
    etat.cooldown <- etat.cooldown +. !projectile_cooldown;
    ship.velocity <- addtuple ship.velocity (polar_to_affine (ship.orientation +. pi) !projectile_recoil)
  done;
  etat.ref_ship <- ref ship;
  ref_etat := etat;
  etat_suivant ref_etat

let teleport ref_etat =
  let etat = !ref_etat in
  if etat.cooldown_tp <= 0. then (
    if !flashes then add_color := hdr_add !add_color (intensify {r=0.;v=4.;b=40.} flashes_teleport);
    game_exposure := !game_exposure *. game_exposure_tp;
    game_speed := ratio_time_tp *. !game_speed;
    let ship = !(etat.ref_ship) in
    let status = wait_next_event[Poll] in
    let newpos = ((float_of_int status.mouse_x) /. !ratio_rendu, (float_of_int status.mouse_y) /. !ratio_rendu) in
    ship.position <- newpos;
    ship.velocity <- (0.,0.);
    etat.ref_chunks_explo <- (spawn_n_chunks ship nb_chunks_explo {r=0.;v=1000.;b=10000.}) @ !ref_etat.ref_chunks_explo;
    etat.ref_ship := ship;
    etat.cooldown_tp <- etat.cooldown_tp +. cooldown_tp;
    ref_etat:=etat)


(*Fonction  de controle souris*)
let controle_souris ref_etat =
  let etat = !ref_etat in
  let ship = !(etat.ref_ship) in
  let status = wait_next_event[Poll] in
  let (xv,yv) = ship.position in
  let (theta, r) =
    affine_to_polar
      ((float_of_int status.mouse_x) /. !ratio_rendu -. xv,
      (float_of_int status.mouse_y) /. !ratio_rendu -. yv) in
  ship.orientation <- theta;
  etat.ref_ship :=  ship;
  ref_etat := etat;
  if status.button && not !pause then acceleration ref_etat else ();;


(*etat une fois mort*)
let rec mort ref_etat =
  game_speed_target := game_speed_target_death;
  game_exposure_target := game_exposure_target_death;
  acceleration ref_etat;
  etat_suivant ref_etat;
  if (Unix.gettimeofday () < !time_of_death +. time_stay_dead_max) && not ((!(!ref_etat.ref_ship).health < ~-. 100.) && (Unix.gettimeofday () > !time_of_death +. time_stay_dead_min)) then (
    controle_souris ref_etat;
    if key_pressed  ()then (
      let status = wait_next_event[Key_pressed] in
        match status.key  with (* ...en fonction de la touche frappee *)
        | 'r' -> ref_etat := init_etat ()(*R permet de recommencer une partie de zéro rapidement.*)
        | 'p' -> pause := not !pause
        | 'k' -> print_endline "Bye bye!"; exit 0 (* on quitte le jeu *)
        | _ -> mort ref_etat)
    else mort ref_etat)
  else (
  if (!ref_etat).lifes <= 0 then (ref_etat := init_etat ();pause := true) else (
  !ref_etat.ref_chunks_explo <- (spawn_n_chunks !(!ref_etat.ref_ship) nb_chunks_explo {r=1500.;v=400.;b=200.}) @ !ref_etat.ref_chunks_explo;
  game_speed := ratio_time_death *. !game_speed;
  game_screenshake := !game_screenshake +. screenshake_death;
  if !flashes then add_color := hdr_add !add_color (intensify {r = 1000. ; v = 0. ; b = 0. } flashes_death);
  !ref_etat.ref_ship <- ref (spawn_ship ());
  game_speed_target := game_speed_target_boucle;
  game_exposure_target := game_exposure_target_boucle));;

(* --- boucle d'interaction --- *)

let rec boucle_interaction ref_etat =
  game_speed_target := game_speed_target_boucle;
  game_exposure_target := game_exposure_target_boucle;

  if !(!ref_etat.ref_ship).health<0. then (
    time_of_death := Unix.gettimeofday ();
    (!ref_etat).lifes <- (!ref_etat).lifes - 1;
    !ref_etat.ref_chunks_explo <- (spawn_n_chunks !(!ref_etat.ref_ship) nb_chunks_explo {r=1500.;v=400.;b=200.}) @ !ref_etat.ref_chunks_explo;
    game_screenshake := !game_screenshake +. screenshake_death;
    if !flashes then add_color := hdr_add !add_color (intensify {r = 1000. ; v = 0. ; b = 0. } flashes_death);
    !(!ref_etat.ref_ship).health <- ~-. 0.1;
  game_speed := ratio_time_death *. !game_speed;
    mort ref_etat;
  );
  controle_souris ref_etat;
  if key_pressed () && not !pause then
  let status = wait_next_event[Key_pressed] in
    match status.key  with (*en fonction de la touche frappee *)
    | 'r' -> ref_etat := init_etat (); pause:=false (*R permet de recommencer une partie de zéro rapidement.*)
    | 'a' -> strafe_left ref_etat; boucle_interaction ref_etat (*strafe vers la gauche *)
    | 'q' -> if !ship_impulse_pos then boost_gauche ref_etat else rotation_gauche ref_etat; boucle_interaction ref_etat (* rotation vers la gauche *)
    | 'z' -> if !ship_impulse_pos then boost ref_etat else acceleration ref_etat; boucle_interaction ref_etat (* acceleration vers l'avant *)
    | 'd' -> if !ship_impulse_pos then boost_droite ref_etat else rotation_droite ref_etat; boucle_interaction ref_etat (* rotation vers la gauche *)
    | 'e' -> strafe_right ref_etat; boucle_interaction ref_etat (*strafe vers la droite *)
    | 'f' -> teleport ref_etat; boucle_interaction ref_etat
    | ' ' -> tir ref_etat;boucle_interaction ref_etat (* tir d'un projectile *)
    | 'p' -> pause := not !pause
    | 'k' -> print_endline "Bye bye!"; exit 0 (* on quitte le jeu *)
    | _ -> etat_suivant ref_etat;boucle_interaction ref_etat
 else if key_pressed() then (
let status = wait_next_event[Key_pressed] in
 match status.key  with (* ...en fonction de la touche frappee *)
   | 'r' -> ref_etat := init_etat (); pause:=false (*R permet de recommencer une partie de zéro rapidement.*)
   | 'p' -> pause := not !pause
   | 'k' -> print_endline "Bye bye!"; exit 0 (* on quitte le jeu *)
   | _ -> etat_suivant ref_etat;boucle_interaction ref_etat
 )else
  etat_suivant ref_etat;
  boucle_interaction ref_etat;;

(* --- fonction principale --- *)

let main () =
  Random.self_init ();
  open_graph (" " ^ string_of_int width ^ "x" ^ string_of_int height);
  auto_synchronize false;

  (* initialisation de l'etat du jeu *)
  let ref_etat = ref (init_etat ()) in

(*On s'assure d'avoir un repère temporel correct*)
  time_last_frame := Unix.gettimeofday();
  time_current_frame := Unix.gettimeofday();
  etat_suivant ref_etat;
  affiche_etat ref_etat;
  boucle_interaction ref_etat;; (* lancer la boucle d'interaction avec le joueur *)

main ();; (* demarrer le jeu *)
