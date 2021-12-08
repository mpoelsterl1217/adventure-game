;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-advanced-reader.ss" "lang")((modname adventure) (read-case-sensitive #t) (teachpacks ()) (htdp-settings #(#t constructor repeating-decimal #t #t none #f () #f)))
(require "adventure-define-struct.rkt")
(require "macros.rkt")
(require "utilities.rkt")

;;;
;;; OBJECT
;;; Base type for all in-game objects
;;;

(define-struct object
  ;; adjectives: (listof string)
  ;; List of adjectives to be printed in the description of this object
  (adjectives)
  
  #:methods
  ;; noun: object -> string
  ;; Returns the noun to use to describe this object.
  (define (noun o)
    (type-name-string o))

  ;; description-word-list: object -> (listof string)
  ;; The description of the object as a list of individual
  ;; words, e.g. '("a" "red" "door").
  (define (description-word-list o)
    (add-a-or-an (append (object-adjectives o)
                         (list (noun o)))))
  ;; description: object -> string
  ;; Generates a description of the object as a noun phrase, e.g. "a red door".
  (define (description o)
    (words->string (description-word-list o)))
  
  ;; print-description: object -> void
  ;; EFFECT: Prints the description of the object.
  (define (print-description o)
    (begin (printf (description o))
           (newline)
           (void))))

;;;
;;; CONTAINER
;;; Base type for all game objects that can hold things
;;;

(define-struct (container object)
  ;; contents: (listof thing)
  ;; List of things presently in this container
  (contents)
  
  #:methods
  ;; container-accessible-contents: container -> (listof thing)
  ;; Returns the objects from the container that would be accessible to the player.
  ;; By default, this is all the objects.  But if you want to implement locked boxes,
  ;; rooms without light, etc., you can redefine this to withhold the contents under
  ;; whatever conditions you like.
  (define (container-accessible-contents c)
    (container-contents c))
  
  ;; prepare-to-remove!: container thing -> void
  ;; Called by move when preparing to move thing out of
  ;; this container.  Normally, this does nothing, but
  ;; if you want to prevent the object from being moved,
  ;; you can throw an exception here.
  (define (prepare-to-remove! container thing)
    (void))
  
  ;; prepare-to-add!: container thing -> void
  ;; Called by move when preparing to move thing into
  ;; this container.  Normally, this does nothing, but
  ;; if you want to prevent the object from being moved,
  ;; you can throw an exception here.
  (define (prepare-to-add! container thing)
    (void))
  
  ;; remove!: container thing -> void
  ;; EFFECT: removes the thing from the container
  (define (remove! container thing)
    (set-container-contents! container
                             (remove thing
                                     (container-contents container))))
  
  ;; add!: container thing -> void
  ;; EFFECT: adds the thing to the container.  Does not update the thing's location.
  (define (add! container thing)
    (set-container-contents! container
                             (cons thing
                                   (container-contents container))))

  ;; describe-contents: container -> void
  ;; EFFECT: prints the contents of the container
  (define (describe-contents container)
    (begin (local [(define other-stuff (remove me (container-accessible-contents container)))]
             (if (empty? other-stuff)
                 (printf "There's nothing here.~%")
                 (begin (printf "You see:~%")
                        (for-each print-description other-stuff))))
           (void))))

;; move!: thing container -> void
;; Moves thing from its previous location to container.
;; EFFECT: updates location field of thing and contents
;; fields of both the new and old containers.
(define (move! thing new-container)
  (begin
    (prepare-to-remove! (thing-location thing)
                        thing)
    (prepare-to-add! new-container thing)
    (prepare-to-move! thing new-container)
    (remove! (thing-location thing)
             thing)
    (add! new-container thing)
    (set-thing-location! thing new-container)))

;; destroy!: thing -> void
;; EFFECT: removes thing from the game completely.
(define (destroy! thing)
  ; We just remove it from its current location
  ; without adding it anyplace else.
  (remove! (thing-location thing)
           thing))

;;;
;;; ROOM
;;; Base type for rooms and outdoor areas
;;;

(define-struct (room container)
  ())

;; new-room: string -> room
;; Makes a new room with the specified adjectives
(define (new-room adjectives)
  (make-room (string->words adjectives)
             '()))

;;;
;;; THING
;;; Base type for all physical objects that can be inside other objects such as rooms
;;;

(define-struct (thing container)
  ;; location: container
  ;; What room or other container this thing is presently located in.
  (location)
  
  #:methods
  (define (examine thing)
    (print-description thing))

  ;; prepare-to-move!: thing container -> void
  ;; Called by move when preparing to move thing into
  ;; container.  Normally, this does nothing, but
  ;; if you want to prevent the object from being moved,
  ;; you can throw an exception here.
  (define (prepare-to-move! container thing)
    (void)))

;; initialize-thing!: thing -> void
;; EFFECT: adds thing to its initial location
(define (initialize-thing! thing)
  (add! (thing-location thing)
        thing))

;; new-thing: string container -> thing
;; Makes a new thing with the specified adjectives, in the specified location,
;; and initializes it.
(define (new-thing adjectives location)
  (local [(define thing (make-thing (string->words adjectives)
                                    '() location))]
    (begin (initialize-thing! thing)
           thing)))

;;;
;;; DOOR
;;; A portal from one room to another
;;; To join two rooms, you need two door objects, one in each room
;;;

(define-struct (door thing)
  ;; destination: container
  ;; The place this door leads to
  (locked? open? destination)
  
  #:methods
  (define (open d)
    (if (door-locked? d)
        (printf "The door is locked.")
        (set-door-open?! d true)))

  ;; unlock: door -> destination
  ;; effect: allows player to open and get through the door to destination
  (define (unlock d key-color)
    (if (string=? key-color "green")
        (set-door-locked?! d false)
        (printf "Wrong key")))

  (define (new-door adjectives locked? destination location)
    (local [(define door (make-door (string->words adjectives)
                                    '() location
                                    true
                                    destination))]
      (begin (initialize-thing! door)
             door)))
  
  
  ;; go: door -> void
  ;; EFFECT: Moves the player to the door's location and (look)s around.
  (define (go door)
    (begin (move! me (door-destination door))
           (look))))

;; join: room string room string
;; EFFECT: makes a pair of doors with the specified adjectives
;; connecting the specified rooms.
(define (join! room1 adjectives1 room2 adjectives2 locked?)
  (local [(define r1->r2 (make-door (string->words adjectives1)
                                    '() room1 locked? #f room2))
          (define r2->r1 (make-door (string->words adjectives2)
                                    '() room2 locked? #f room1))]
    (begin (initialize-thing! r1->r2)
           (initialize-thing! r2->r1)
           (void))))


;;;
;;; PROP
;;; A thing in the game that doesn't serve any purpose other than to be there.
;;;

(define-struct (prop thing)
  (;; noun-to-print: string
   ;; The user can set the noun to print in the description so it doesn't just say "prop"
   noun-to-print
   ;; examine-text: string
   ;; Text to print if the player examines this object
   examine-text
   )
  
  #:methods
  (define (noun prop)
    (prop-noun-to-print prop))

  (define (examine prop)
    (display-line (prop-examine-text prop))))

;; new-prop: string container -> prop
;; Makes a new prop with the specified description.
(define (new-prop description examine-text location)
  (local [(define words (string->words description))
          (define noun (last words))
          (define adjectives (drop-right words 1))
          (define prop (make-prop adjectives '() location noun examine-text))]
    (begin (initialize-thing! prop)
           prop)))

;;;
;;; Organism
;;; A type for all living things in the game, handles eating
;;;
(define-struct (organism prop)
  (hunger)
  #:methods
  ;; feed: organism thing -> void
  ;; checks if organism can eat the thing, if so then it is removed and fullness of organism is updated
  (define (feed an-organism a-thing)
    (if (can-eat? an-organism a-thing)
        (begin (destroy! a-thing)
               (set-organism-hunger! an-organism
                                     (- (organism-hunger an-organism)
                                        (food-fillingness a-thing)
                                        )
                                     )
               (if (positive? (organism-hunger an-organism))
                   (printf "~A is still hungry.~%"
                           (noun an-organism)
                           )
                   (if (negative? (organism-hunger an-organism))
                       (printf "~A is full.~%"
                               (noun an-organism)
                               )
                       (printf "~A is satisfied.~%"
                               (noun an-organism)
                               )
                       )
                   )
               )
        (printf "~A cannot eat that.~%"
                (noun an-organism)
                )
        )
    )
  ;; can-eat?: organism thing -> boolean
  ;; output represents if the organism can eat the thing, helper to feed
  ;; parent method to be overrided by children
  (define (can-eat? an-organism a-thing)
    (food? a-thing)
    )
  )

;;;
;;; PERSON
;;; A character in the game.  The player character is a person.
;;;

(define-struct (person organism)
  (;; outfit: a container that holds all clothes a person is wearing
   outfit
   )
  #:methods
  (define (container-accessible-contents p)
    (append (container-accessible-contents (person-outfit p))
            (container-contents p)
            )
    )
  (define (can-eat? a-person a-thing)
    (if (food? a-thing)
        (if (food-for-human? a-thing)
            (if (food-needs-spoon? a-thing)
                (> (length (filter (λ (item)
                                     (if (is-a? item 'utensil)
                                         (symbol=? (utensil-kind item) 'spoon)
                                         #f
                                         )
                                     )
                                   (container-contents a-person)
                                   )
                           )
                   0
                   )
                (if (food-needs-knife? a-thing)
                    (> (length (filter (λ (item)
                                         (if (is-a? item 'utensil)
                                             (symbol=? (utensil-kind item) 'knife)
                                             #f
                                             )
                                         )
                                       (container-contents a-person)
                                       )
                               )
                       0
                       )
                    #t
                    )
                )
            #f
            )
        #f
        )
    ))

;; initialize-person: person -> void
;; EFFECT: do whatever initializations are necessary for persons.
(define (initialize-person! p)
  (initialize-thing! p))

;; new-person: string container -> person
;; Makes a new person object and initializes it.
(define (new-person adjectives location pronoun)
  (local [(define person
            (make-person (string->words adjectives)
                         '()
                         location
                         pronoun
                         "It's a person"
                         (random 5) ;; Sets hunger to a random natural number in [0,5)
                         (make-container "outfit" '())
                         ))]
    (begin (initialize-person! person)
           person)))

;; This is the global variable that holds the person object representing
;; the player.  This gets reset by (start-game)
(define me empty)


;;;
;;; ADD YOUR TYPES HERE!                                                                      
;;; 


;;; food

(define-struct (food prop)
  (fillingness for-human? needs-spoon? needs-knife?)
  )

;;; new-food
(define (new-food description examine-text location fillingness for-human? needs-spoon? needs-knife?)
  (local [(define words (string->words description))
          (define noun (last words))
          (define adjectives (drop-right words 1))
          (define food (make-food adjectives '() location noun examine-text fillingness for-human? needs-spoon? needs-knife?))]
    (begin (initialize-thing! food)
           food)))
  
               
;;; utensil
;;; utensils (spoon and knife) needed to eat
(define-struct (utensil prop)
  (kind))

;;; new-utensil
(define (new-utensil description examine-text location kind)
  (local [(define words (string->words description))
          (define noun (last words))
          (define adjectives (drop-right words 1))
          (define utensil (make-utensil adjectives '() location noun examine-text kind))]
    (begin (initialize-thing! utensil)
           utensil
           )
    )
  )


;;; key
;;; A colored key needed to open the front door
(define-struct (key prop)
  (color))

;;; new-key
(define (new-key description examine-text location color)
  (local [(define words (string->words description))
          (define noun (last words))
          (define adjectives (drop-right words 1))
          (define key (make-key adjectives '() location noun examine-text color))]
    (begin (initialize-thing! key)
           key
           )
    )
  )

;;;
;;; Clothing
;;; Clothes that can be taken on and off
;;;
(define-struct (clothing prop)
  (;; kind: symbol
   ;; symbol representing what type of clothing the item is (values: hat, shirt, pants, shoes, gloves, jacket)
   kind
   ;; warmth
   ;; number representing a how "warm" an item is (ie. warmth = 20 represents an item that makes you feel 20 degrees warmer)
   warmth
   )
  #:methods
  ;; don: clothing -> void
  ;; Puts on a clothing item
  ;; EFFECT: add item to player's outfit if slot is open
  (define (don new-item)
    (if (ormap (λ (current-item)
                 (symbol=? (clothing-kind new-item) (clothing-kind current-item))
                 )
               (my-outfit)
               )
        (printf "You are already wearing a ~A.~%"
                (symbol->string (clothing-kind new-item))
                )
        (move! new-item (person-outfit me))
        )
    )
  ;; doff: clothing -> void
  ;; Takes off a clothing item 
  ;; EFFECT: removes item from player's outfit if wearing
  (define (doff item)
    (if (member item
                (my-outfit)
                )
        (move! item (here))
        (printf "You aren't wearing ~A.~%"
                (description item)
                )
        )
    )
  )
;; new-clothing: string string container symbol number -> clothing
;; creates and initializes a new clothing object
(define (new-clothing description examine-text location type warmth)
  (local [(define words (string->words description))
          (define noun (last words))
          (define adjectives (drop-right words 1))
          (define item (make-clothing adjectives '() location noun examine-text type warmth))]
    (begin (initialize-thing! item)
           item
           )
    )
  )

;;;
;;; Animal
;;; An animal in the game that can be pet and fed 
;;;
(define-struct (animal organism)
  (friendliness)
  #:methods
  (define (pet an-animal)
    (begin (set-animal-friendliness! an-animal
                                     (* 2
                                        (+ 1 (animal-friendliness an-animal))
                                        )
                                     )
           (if (< (animal-friendliness an-animal)
                  -10
                  )
               (begin (destroy! an-animal)
                      (printf "The ~A ran away.~%"
                              (noun an-animal)
                              )
                      )
               (cond [(positive? (animal-friendliness an-animal))
                      (printf "The ~A seems to like you.~%"
                              (noun an-animal)
                              )
                      ]
                     [(negative? (animal-friendliness an-animal))
                      (printf "The ~A seems to not like you.~%"
                              (noun an-animal)
                              )
                      ]
                     [else 
                      (printf "The ~A seems ambivalent to you.~%"
                              (noun an-animal)
                              )
                      ]
                     )
               )
           )
    )
  )
;; new-animal:
;; creates and initializes a new animal with random hunger and friendliness in [-5, 5]
(define (new-animal description examine-text location)
  (local [(define words (string->words description))
          (define adjectives (drop-right words 1))
          (define noun (last words))
          (define my-hunger (- 5 (random 11)))
          (define my-friendliness (- 5 (random 11)))
          (define an-animal (make-animal adjectives '() location noun examine-text my-hunger my-friendliness))]
    (begin (initialize-thing! an-animal)
           an-animal
           )
    )
  )

;;bag
(define-struct (bag prop)
  (openZip? capacity)

  #:methods

  (define (zipOpen-bag b)
    (set-bag-openZip?! b true))

  (define (zipClose-bag b)
    (set-bag-openZip?! b false))

  (define (putIn-bag b thing)
    (if (bag-openZip? b)
        (if (< (length(container-contents b)) (bag-capacity b) )
            (begin (set-container-contents! b
                                      (cons thing
                                            (container-contents b)))
                   (set-bag-capacity! b (+ 1 bag-capacity b)))
            (printf "Sorry, this bag is full! Empty it before adding something!"))
        (printf "Open the bag first!")
        ))


  (define (takeOut-bag b thing)
    (if (bag-openZip? b)
        (set-container-contents! b
                           (remove! thing
                                   (container-contents b)))
    #f)
  ))

(define (new-bag description examine-text location capacity)
  (local [(define words (string->words description))
          (define noun (last words))
          (define adjectives (drop-right words 1))
          (define the-bag (make-bag adjectives '() location noun examine-text false capacity
                                    ))]
    (begin (initialize-thing! the-bag)
           the-bag)))


;;phone

(define-struct (phone prop)
  (temperature time weather)
  #:methods
  (define (check-temperature p)
    (phone-temperature p)
    )
  (define (check-time p)
    (phone-time p))
  (define (check-weather p)
    (phone-weather p)))


(define (new-phone description examine-text location temperature my-time weather)
  (local [(define words (string->words description))
          (define noun (last words))
          (define adjectives (drop-right words 1))
          (define the-phone (make-phone adjectives
                                        '()
                                        location
                                        noun
                                        examine-text
                                        temperature
                                        my-time
                                        weather))]
    (begin (initialize-thing! the-phone)
           the-phone)))

;;;
;;; USER COMMANDS
;;;

(define (look)
  (begin (printf "You are in ~A.~%"
                 (description (here)))
         (describe-contents (here))
         (void)))

(define-user-command (look) "Prints what you can see in the room")

(define (inventory)
  (if (empty? (my-inventory))
      (printf "You don't have anything.~%")
      (begin (printf "You have:~%")
             (for-each print-description (my-inventory)))))

(define-user-command (inventory)
  "Prints the things you are carrying with you.")

(define-user-command (examine thing)
  "Takes a closer look at the thing")

(define (take thing)
  (move! thing me))

(define-user-command (take thing)
  "Moves thing to your inventory")

(define (drop thing)
  (move! thing (here)))

(define-user-command (drop thing)
  "Removes thing from your inventory and places it in the room
")

(define (put thing container)
  (move! thing container))

(define-user-command (put thing container)
  "Moves the thing from its current location and puts it in the container.")

(define (help)
  (for-each (λ (command-info)
              (begin (display (first command-info))
                     (newline)
                     (display (second command-info))
                     (newline)
                     (newline)))
            (all-user-commands)))

(define-user-command (help)
  "Displays this help information")

(define-user-command (go door)
  "Go through the door to its destination")

(define (check condition)
  (if condition
      (display-line "Check succeeded")
      (error "Check failed!!!")))

(define-user-command (check condition)
  "Throws an exception if condition is false.")

;;;
;;; ADD YOUR COMMANDS HERE!
;;;
(define (outfit)
  (if (empty? (my-outfit))
      (printf "You aren't wearing anything.~%")
      (begin (printf "You are wearing:~%")
             (for-each print-description (my-outfit))
             )
      )
  )
(define-user-command (outfit)
  "Prints the things you are wearing")

(define-user-command (don clothing-item)
  "Puts on the clothing-item, unless you are already wearing something there")

(define (eat a-thing)
  (feed me a-thing)
  )

(define-user-command (unlock door key-color)
  "Try to unlock the door using the special colored-key")

;;;
;;; THE GAME WORLD - FILL ME IN
;;;

;; bedroom
;; contains: clothes, phone, key

;; kitchen
;; contains: foods, utensils, key

;; hall
;; contains: a bag, cat, key

;; start-game: -> void
;; Recreate the player object and all the rooms and things.
(define (start-game)
  ;; Fill this in with the rooms you want
  (local [(define bedroom (new-room "small cozy bedroom"))
          (define kitchen (new-room "happy kitchen"))
          (define hall (new-room "colorful long hall"))
          (define outside (new-room "the outside"))
          ]
    (begin (set! me (new-person "" bedroom "me"))
           ;; Add join commands to connect your rooms with doors
           (join! bedroom "kitchen"
                  kitchen "bedroom"
                  false)
           (join! kitchen "hall"
                  hall "kitchen"
                  false)
           (join! hall "front"
                  outside "entry"
                  true)
           
           ;; Add code here to add things to your rooms
           ;; Things in bedroom
           ; phone
           (new-phone "new phone" "my cool new phone" bedroom 30 "9:00am" "cloudy")
           
           ; clothes
           (new-clothing "hat" "Look, my winter hat" bedroom 'hat 15)
           (new-clothing "shirt" "my favorite shirt" bedroom 'shirt 10)
           ; key
           (new-key "blue-key" "The blue key!" bedroom "blue")

           ;; Things for kitchen
           (new-food "big yellow banana" "it's a banana" kitchen 1 #t #f #f)
           (new-food "bowl of soup" "it's a good soup" kitchen 2 #t #t #f)
           (new-food "big steak" "it's a steak alright" kitchen 3 #t #f #t)
           ; utensils
           (new-utensil "shiny spoon" "a clean spoon!" kitchen 'spoon)
           (new-utensil "sharp knife" "it's a knife!" kitchen 'knife)
           ;;key
           (new-key "red-key" "I found the red key!" kitchen "red")
           
           ;; Things for hall
           ; bag
           (new-bag "black backpack" "my backpack" hall 3)
           ; animal
           (new-animal "small black cat" "It's a cat" kitchen)
           ; key
           (new-key "green-key" "Oh look, a green key!" hall "green")
           
           (check-containers!)
           (void))))

;;; PUT YOUR WALKTHROUGHS HERE

(define-walkthrough win
  (check-temperature (the phone))
  (take (the phone))
  (don (the shirt))
  (take (the key))
  (inventory)
  (go (the door))
  (take (the spoon))
  (eat (the soup))
  (feed (the cat) (the steak))
  (pet (the cat))
  (take (the "red-key"))
  (inventory)
  (go (the hall door))
  (check-time (the phone))
  (take (the "green-key"))
  (inventory)
  (go (the front door)))


;;;
;;; UTILITIES
;;;

;; here: -> container
;; The current room the player is in
(define (here)
  (thing-location me))

;; stuff-here: -> (listof thing)
;; All the stuff in the room the player is in
(define (stuff-here)
  (container-accessible-contents (here)))

;; stuff-here-except-me: -> (listof thing)
;; All the stuff in the room the player is in except the player.
(define (stuff-here-except-me)
  (remove me (stuff-here)))

;; my-inventory: -> (listof thing)
;; List of things in the player's pockets.
(define (my-inventory)
  (container-accessible-contents me))

;; my-outfit: -> (listof clothing)
;; List of clothing that the player is wearing
(define (my-outfit)
  (container-accessible-contents (person-outfit me))
  )

;; accessible-objects -> (listof thing)
;; All the objects that should be searched by find and the.
(define (accessible-objects)
  (append (stuff-here-except-me)
          (my-inventory)))

;; have?: thing -> boolean
;; True if the thing is in the player's pocket.
(define (have? thing)
  (eq? (thing-location thing)
       me))

;; have-a?: predicate -> boolean
;; True if the player as something satisfying predicate in their pocket.
(define (have-a? predicate)
  (ormap predicate
         (container-accessible-contents me)))

;; find-the: (listof string) -> object
;; Returns the object from (accessible-objects)
;; whose name contains the specified words.
(define (find-the words)
  (find (λ (o)
          (andmap (λ (name) (is-a? o name))
                  words))
        (accessible-objects)))

;; find-within: container (listof string) -> object
;; Like find-the, but searches the contents of the container
;; whose name contains the specified words.
(define (find-within container words)
  (find (λ (o)
          (andmap (λ (name) (is-a? o name))
                  words))
        (container-accessible-contents container)))

;; find: (object->boolean) (listof thing) -> object
;; Search list for an object matching predicate.
(define (find predicate? list)
  (local [(define matches
            (filter predicate? list))]
    (case (length matches)
      [(0) (error "There's nothing like that here")]
      [(1) (first matches)]
      [else (error "Which one?")])))

;; everything: -> (listof container)
;; Returns all the objects reachable from the player in the game
;; world.  So if you create an object that's in a room the player
;; has no door to, it won't appear in this list.
(define (everything)
  (local [(define all-containers '())
          ; Add container, and then recursively add its contents
          ; and location and/or destination, as appropriate.
          (define (walk container)
            ; Ignore the container if its already in our list
            (unless (member container all-containers)
              (begin (set! all-containers
                           (cons container all-containers))
                     ; Add its contents
                     (for-each walk (container-contents container))
                     ; If it's a door, include its destination
                     (when (door? container)
                       (walk (door-destination container)))
                     ; If  it's a thing, include its location.
                     (when (thing? container)
                       (walk (thing-location container))))))]
    ; Start the recursion with the player
    (begin (walk me)
           all-containers)))

;; print-everything: -> void
;; Prints all the objects in the game.
(define (print-everything)
  (begin (display-line "All objects in the game:")
         (for-each print-description (everything))))

;; every: (container -> boolean) -> (listof container)
;; A list of all the objects from (everything) that satisfy
;; the predicate.
(define (every predicate?)
  (filter predicate? (everything)))

;; print-every: (container -> boolean) -> void
;; Prints all the objects satisfying predicate.
(define (print-every predicate?)
  (for-each print-description (every predicate?)))

;; check-containers: -> void
;; Throw an exception if there is an thing whose location and
;; container disagree with one another.
(define (check-containers!)
  (for-each (λ (container)
              (for-each (λ (thing)
                          (unless (eq? (thing-location thing)
                                       container)
                            (error (description container)
                                   " has "
                                   (description thing)
                                   " in its contents list but "
                                   (description thing)
                                   " has a different location.")))
                        (container-contents container)))
            (everything)))

;; is-a?: object word -> boolean
;; True if word appears in the description of the object
;; or is the name of one of its types
(define (is-a? obj word)
  (let* ((str (if (symbol? word)
                  (symbol->string word)
                  word))
         (probe (name->type-predicate str)))
    (if (eq? probe #f)
        (member str (description-word-list obj))
        (probe obj))))

;; display-line: object -> void
;; EFFECT: prints object using display, and then starts a new line.
(define (display-line what)
  (begin (display what)
         (newline)
         (void)))

;; words->string: (listof string) -> string
;; Converts a list of one-word strings into a single string,
;; e.g. '("a" "red" "door") -> "a red door"
(define (words->string word-list)
  (string-append (first word-list)
                 (apply string-append
                        (map (λ (word)
                               (string-append " " word))
                             (rest word-list)))))

;; string->words: string -> (listof string)
;; Converts a string containing words to a list of the individual
;; words.  Inverse of words->string.
(define (string->words string)
  (string-split string))

;; add-a-or-an: (listof string) -> (listof string)
;; Prefixes a list of words with "a" or "an", depending
;; on whether the first word in the list begins with a
;; vowel.
(define (add-a-or-an word-list)
  (local [(define first-word (first word-list))
          (define first-char (substring first-word 0 1))
          (define starts-with-vowel? (string-contains? first-char "aeiou"))]
    (cons (if starts-with-vowel?
              "an"
              "a")
          word-list)))

;;
;; The following calls are filling in blanks in the other files.
;; This is needed because this file is in a different langauge than
;; the others.
;;
(set-find-the! find-the)
(set-find-within! find-within)
(set-restart-game! (λ () (start-game)))
(define (game-print object)
  (cond [(void? object)
         (void)]
        [(object? object)
         (print-description object)]
        [else (write object)]))

(current-print game-print)
   
;;;
;;; Start it up
;;;

(start-game)
(look)

