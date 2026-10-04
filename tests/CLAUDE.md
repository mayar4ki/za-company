# Tests - what every suite owns, and how to write a check

How to run them, the one-suite-one-world rule and what the export presets leave
out are the root CLAUDE.md's *Testing*. This is the rest.

## The suites

- `tests/` holds SceneTree-script tests: no framework, no dependencies.
  They drive the real game with synthesized input and exit 0/1. Forty-six suites,
  each extending `tests/helpers.gd` (the shared harness: checks, key synthesis,
  settings backup, node getters) and overriding `_tick(frame)`:
  - `test_menu.gd` - main menu (HOST ONLINE and JOIN ONLINE, no MODE),
    character select, the settings panel from the main menu - its DIFFICULTY
    row and the scaling it decides, and the pause menu's copy hiding that row
    - and the menu music holding ONE player across all three front-end scenes
    (checked by object id, since a headless run has no audio device to ask).
    Never enters the game.
  - `test_flow.gd` - the journey through ONE room and the end of a run:
    select -> game -> movement -> pause -> zoom -> blow -> heart -> death ->
    wall -> back to the menu -> a second run that spends every life -> game
    over. The doors are test_chain.gd's.
  - `test_chain.gd` - the walk up the building: lobby to penthouse on foot
    through every door and one door back down, asserting each room's own
    composition and dressing as it passes, plus the music handed from floor to
    floor, and each boss floor's bar and theme, with Ahmed and Silverman
    conceded the short way. It is built from
    LEGS - one function per floor, handed frames counted from its own arrival,
    and a table of how long each lasts - so **inserting a floor is one leg
    function and one `LEGS` row**, and no other leg is renumbered. It sets 100%
    zoom itself before the run, because every door's "camera reframed" check
    wants the whole room framed.
  - `test_combat.gd` - guard telegraph and interrupts, wraith, warden, heavy,
    and the leash: that losing sight of the player does not stop a chase, that
    it ends 2.5s later, that the body walks back to the spot it was placed on,
    and that kiting drags it exactly 160 px and no further.
  - `test_hit_feel.gd` - what a landed blow does besides the damage: the
    hit-stop, the white flash, the recoil, the numbers over the enemies, the
    kill burst, the static charge and the arc preferring a charged body, the
    juggle with the BODY never moving, the thunderclap's flash and crackle, the
    supernova's embers, blast and stop, the room back at full speed after, and
    a boss never reeling. It LATCHES rather than reading frame numbers - every
    effect is brief and the hit-stop itself stretches time, so it asks every
    frame "was it seen" and answers at the end. Note for every frame-numbered
    suite: a landed hit now stops the room for a few frames, so a check timed
    to the end of an attack that LANDS needs slack (test_arc.gd moved by 6).
  - `test_dodge.gd` - the roll, stage after stage in the empty lobby: K and
    Z and never Ctrl; all ten characters' three rows, pixel
    for pixel what tools/roll_pose.gd makes of the RECOLOURED sheet, and no
    roll in the source PNG; exactly 48 px in 20 frames the way the stick
    points, backwards with it at rest, the walk after, the cooldown and the
    dust settling, and the `dodge` cue said once per roll and never for a
    press the cooldown or the heavy refuses; a blow probed on EVERY frame of
    a roll, missing exactly
    inside 0.04-0.26 and landing either side, while a drain and a slow land
    straight through; a swing and a charge cut short, never the heavy, a swing
    pressed mid-roll going off at its end, and a slow halving it. Then a real
    guard: seen landing his blow with no roll, then missing the same blow
    struck mid-roll against the wall, where the roll cannot carry the body out
    of reach. Last, the host trusting a teammate's word that it is rolling, and
    the teammate's picture kicking up its dust and making its sound. It reads
    player.gd's numbers
    off the live body's script, never by preload - this file compiles before
    the autoloads exist, and player.gd names one.
  - `test_slam.gd` - the fourth archetype: that the ring draws the Touch
    shape's own reach (a retune that moves the hitbox and leaves the drawing
    behind is a bug nobody can see), that the wind-up telegraphs without
    hurting, that the blow costs EXACTLY the node's own scaled damage rather
    than merely something, that it throws the player and that the push then
    wears off, that a committed slam still lands on air when the ring is empty,
    and that 48 is a combo breakpoint and exactly two heavies - read off
    player.gd's own constants, so retuning either side fails here. Its headline
    check is the placement band swept across the whole chain off disk: a 90 px
    sight has its own bracket around each room's OWN walk, asked of the level
    rather than written down here - so the shaped floor is measured where its
    walk really is - and a brute is found by
    having `shove_force` rather than by its type, so a second one is covered the
    day it exists. Its own suite because everything else in combat measures a
    player who stays put, and this one moves them.
  - `test_bosses.gd` - Ahmed's attacks, the order he picks them in, the
    interrupt and the concede.
  - `test_ahmed_moves.gd` - Ahmed's attacks one at a time, each staged with a
    FRESH Ahmed so no cooldown or alternation leaks between them: backing
    straight off a chop is caught by the fissure's pillars (8, not 16), the
    sweep pushes you out of his reach, the leap's ring goes down where you
    stand as he jumps and he comes down on it, the gap between two of the
    fan's waves is safe, and three seconds of keeping away earns the chair -
    spun, rolled, landed, dizzy for its 1.55 s. Plus the weight: the hit-stop
    really slows the room, really lets it go, and is asked for by signal like
    the shake. Its own suite because every stage needs him fighting ONE way,
    which is the opposite of test_bosses.gd running the fight he picks.
  - `test_big_mo_moves.gd` - Big Mo's four later additions on the same
    terms, a FRESH Big Mo per stage: a string is jab, jab, then a hook or an
    uppercut and never three of one running; the uppercut reaches 30 px down
    his line and misses one step aside, while the hook is the other way round;
    the corner rush stands still through its crouch, lands on a player who
    stays on his line 70 px out, and misses one who steps up or down 0.40 s
    after it begins (a reaction, by `_key`, not a teleport);
    three quick hits shell him, a hit on the shell is blocked (no health off)
    and countered for 12 by an attack that cannot be mashed out of, and a
    shell waited out opens his guard to hits and does not come back inside its
    cooldown; pressed against him he clinches, costs 8 and throws you clear of
    his reach; raging, every other string is the flurry, the breath is 0.4,
    and the flurry walks you back while he marches after you.
  - `test_rage.gd` - Big Mo going up at 72 and staying up: that it fires at
    half health and not before, fires once, roots and silences him without
    letting him be staggered, never comes back down, and that every beat of
    the fire still lands on a frame boundary. Its own suite because it needs
    him FIGHTING and then taken across the line on a chosen frame, which
    threaded through the three-boss file made one boss's timing decide
    another's.
  - `test_silverman.gd` - his whole ladder: the glare opening at range with no
    contact, the crossing that passes THROUGH the player for one blow, the
    split's copy walking you down, the cold room draining outside the grace
    window, and the third phase refusing to be staggered. Its own suite because
    the fight walks him down three phases, so every check after the first
    depends on how much health he has left - a file that does that cannot also
    hand the room to a next section unchanged. test_bosses.gd keeps the art
    invariants that hold at any health. It isolates by GEOMETRY rather than by
    frame number: his band is a 20 px lane and his crossing only moves along x,
    so a player parked 30 px off his line is untouchable by both while the copy,
    which homes in two dimensions, still reaches them.
  - `test_barks.gd` - what Ahmed shouts: the hello, the taunt when he is
    kited, an attack announcing itself on the wind-up, being interrupted and
    being merely hurt saying different things, the concede line jumping the
    queue, and the subtitle taking itself down. Its own suite because a taunt
    needs a boss who never reaches anybody, which is the exact opposite of the
    fight test_bosses.gd runs. It also keeps the two checks that are about
    talking rather than about Ahmed: that a boss whose `Lines` child is TORN
    OFF is silent and still fights (it used to ask this of whichever boss was
    still mute, and there is no longer one), and the sweep of Silverman's file
    off disk - every line said twice with the halves differing, every clip
    really on disk, no two lines sharing one, and every cue he speaks on a cue
    something fires. An English-only line is legal everywhere else in the game,
    so nothing but that sweep would notice him stopping.
  - `test_reinforcements.gd` - a later beat's trigger, its single-file
    arrival, the door it uses, the hold while the player stands in that door,
    that a beat fires once, and the head count. Builds the beat by hand in the
    empty lobby rather than walking nine floors to the one biome that has one.
  - `test_ivan.gd` - the third beat: that he waits for a fight and not
    merely for a quiet room, that he comes in by the door and crosses to his
    spot, that a late arrival can still be talked to (game.gd wires NPCs as
    they arrive, which is the failure that would be silent on six floors),
    that the hearts land on the last word and heal, one per head, once. Builds
    the beat by hand in the empty lobby, then checks the six floors off disk -
    that each carries the beat, sends him to its own spot, and gives him its OWN
    conversation. It also sweeps all six of those: every line names a clip,
    every clip is on disk, no two floors share a clip (they cut into one folder,
    so a collision silently plays another floor's read) and no two floors say
    the same line, which is the whole reason there are six files.
  - `test_dominique.gd` - the fourth beat, the one that hands over information
    rather than a heart: that they wait for a fight and not merely for a quiet
    room, that they come down the NORTH door while Ivan comes up the south one,
    that they cross to the spot and can be talked to after arriving late, and
    that nothing is healed by any of it. Its own suite because test_ivan.gd
    ends by hurting the player and counting hearts, and this one has to prove
    no heart is ever thrown. It also checks the RULE the three floors are only
    an instance of - a briefing under every boss floor and under no other - by
    reading the whole chain off disk, so a fourth boss cannot ship unannounced.
  - `test_reward.gd` - a cleared room's hearts (game/levels/reward.gd), built
    by hand in the empty lobby the way test_ivan.gd builds its beat: nothing in
    a room never fought, nothing while a body stands, then a real office boy
    killed and one heart where he fell, live, healing when walked onto, and
    gone once taken; a second fight in the same visit drops nothing; and with a
    second head and a stand-in second beat, nothing until the beat is spent,
    then two hearts round the spot and not on top of each other. Ends by
    checking the innovation lab carries one off disk and the lobby does not.
  - `test_enemy_sfx.gd` - the bestiary's noise: that all six own the cues
    their archetype can actually reach and no cue it can never reach, that
    every declared stream resolves, that the wraith's drain is a sealed loop
    rather than a one-shot with a flag on it, and that a death sound outlives
    the body that made it. Its own suite because that last one is destructive
    - it kills an enemy and counts what the room is left holding. What it
    deliberately does NOT check is that a one-shot is audible: headless has no
    `playing` and `--fixed-fps` makes `get_playback_position()` a coin flip
    (see test_menu.gd's note), so the evidence is structure plus the two calls
    that leave a visible mark - the loop flag, and the detached player. It
    also keeps the two mutterers: that each names its OWN lines file, that
    every line has a clip that really resolves (a missing one is legal and
    silent, so a typo is an enemy who moves their lips), that the poll gets a
    line out, that six spawned together do not share one countdown, and that
    none of it reaches the subtitle.
  - `test_dialogue.gd` - HR's whole induction: the prompt, the typewriter, a
    dead stick while she talks, the choices and the branch one takes, the
    escorted tour, the contract, and the wheel coming back. Driven by what is
    on screen rather than by frame numbers - a line's LENGTH is its duration,
    so numbered frames would need re-timing every time one is reworded. It also
    keeps her VOICE, and the check that matters there is not that audio is
    playing (see the wall-clock note below) but that the line is typed at the
    CLIP's rate rather than the flat one: that is arithmetic the game did on
    the stream's own length, so it can only pass if the clip was really found,
    loaded and applied, and it does not depend on the wall clock at all. Plus
    the sweep a silent-by-design miss needs: every line she speaks names a
    clip, and every clip named is on disk.
  - `test_player_sfx.gd` - the player's own noise: that the body declares
    every cue player.gd can fire and no cue it never will, that each resolves,
    that the charge stance is a sealed LOOP rather than a one-shot with a flag
    on it, and - the part that is not test_enemy_sfx.gd over again - that a
    body with its `Audio` child torn off still swings, still charges and still
    takes a hit. That last one is the promise the whole design rests on and is
    destructive, which is why this is its own suite. It measures a loop seam
    against the clip's WORST internal step where the bestiary's suite uses the
    mean, because the charge bed is quiet in the export and takes a large
    make-up gain: its samples land on a coarse quantization grid with a median
    step of zero, and a mean no actual step is near fails a perfect join.
  - `test_studio.gd` - floor 2's clock and the two things that read it: that a
    lamp with no clock in the room is furniture (checked in the LOBBY, because
    a promise about absence has to be tested where the thing is absent), that
    the cue warms the pools and the sign without hurting anybody, that the
    take then burns and the rig runs, and that a rig being pushed back to its
    mark is harmless even parked on top of you. Its own suite because checking
    a rhythm means standing still in one room for eleven seconds, which is the
    opposite of every other file here; test_chain.gd keeps only that the
    dressing still carries the clock. It also guards the one invariant a
    moving hazard could break without ever being placed: the rail's span
    against the door lane.
  - `test_scrubber.gd` - floor 5's wandering machines, and the shove they
    arrived with. Every check is a PROPERTY rather than a position, because
    there is no authored route to compare against: neither machine left its pen
    in 420 sampled frames, neither was ever on the door lane, both covered
    ground rather than wedging in a corner, and a staged bump costs health and
    position together. Then the push on its own terms - it moves you, it wears
    off, and three at once move you no further than one. The bump is STAGED (a
    machine placed beside the player and aimed) rather than waited for: standing
    about hoping to be found is a check that passes on a seed, and starting the
    machine far away makes the contact frame depend on the travel, which is what
    made the first version flaky.
  - `test_music.gd` - the finale across a door: that an ordinary floor plays
    the bed, that floor 11 gets the track its biome names, that the stream
    really resolved and its loop is sealed to the stream's real length, that
    the door into the penthouse does not restart it, that the boss standing
    there names no theme of his own, and the RULE those two floors are only an
    instance of - read off disk, so a `music` line pasted onto a room in the
    middle of the building fails here. Its own suite because it is the first
    check in this project that spans a DOOR rather than sitting in one room.
    The no-restart check SEEKS the playhead to 30 s before travelling rather
    than reading the position twice: headless mixing crawls (0.09 s across 160
    frames), so "the position advanced" is a coin flip that would pass a
    restart on a quiet frame, while a playhead parked where no fresh `play()`
    could leave it either survives the door or does not.
  - `test_ui_sound.gd` - the menu's noise, and mostly the half that is about
    SILENCE: that opening the menu does not chime at itself, that arrowing
    between options ticks exactly once, that a panel taking focus is not a
    move, that a dropdown's own list ticks too (a PopupMenu never takes focus,
    so nothing else would notice it going quiet), that three plays on one frame
    are one sound, and - the one that pays for `back` not being a global
    `ui_cancel` handler - that Escape on the death screen is swallowed AND
    silent, while the same key in the same screen chimes when it does
    something. Its own suite because every check is a DELTA on a play count, so
    it has to own the focus state of the screen for its whole length, which is
    exactly what test_menu.gd's later sections are busy moving about. It reads
    a count kept where the sound is really started rather than `playing` or
    `get_playback_position()`, for that file's stated reasons - and a
    SUPPRESSED play is invisible in every other way. It builds the death screen
    by hand rather than by dying, the way test_reinforcements.gd builds its
    beat.
  - `test_surge.gd` - floor 3's wiring: that a charging line warns without
    hurting, that the head then crosses whoever stood on it, that the drop is
    exactly the node's own scaled damage rather than merely non-zero (one pass
    is one hit, which is what makes four runs fair), that the head parks off
    the line between runs, and that the cycle comes round again. Its headline
    check is the walk swept along all four runs - a surge is the second thing
    that could threaten the route between the doors without being placed on it,
    and unlike the dolly there are four. It samples ALONG a run rather than
    comparing two numbers, because two of this floor's four are vertical and a
    check that knew the lane was a band of x would pass them without looking.
  - `test_steering.gd` - getting round the furniture: that a guard with two
    desks between it and the player arrives anyway and swings, that it got
    there by going AROUND rather than by some accident of the geometry, that a
    body with no way round stops trying and walks home instead of grinding,
    that an enemy with nothing in its way still walks a dead straight line, and
    that the smallest prop in the game gets the same treatment as the biggest.
    Its own suite because it needs
    a room arranged WRONG - every floor in the game is dressed so the fight
    works, so none of them can ask this - and it builds the bad case by hand in
    the empty lobby, the way test_reinforcements.gd builds its beat.
  - `test_dogleg.gd` - the floor that is not a rectangle, and the two things a
    shaped room can break that a rectangular one never could. The one that
    generalizes is swept across the whole chain off disk: every floor's walk is
    floor END TO END, and it runs between the two DOORS rather than past them -
    a prop moved twenty pixels or a cut redrawn a tile lower is a floor nobody
    can finish, and it looks fine in the data. The other is the corner: a body
    in the arm with the building between it and the player gets round it, which
    is test_steering.gd's question asked about eight tiles of masonry instead of
    a desk. What it deliberately does NOT treat as a failure is a beat that
    arrives and then stands there - a reinforcement has no post and therefore no
    patience, so it hunts only what it can see, on this floor exactly as on the
    other eleven. Staging that wrong looks identical to a wedge, which is why
    the suite measures its own premise before it measures the answer.
  - `test_alert.gd` - the room alert: that the doorway wakes nobody, that
    walking on towards the far door sets a guard far out of sight hunting, that
    a reinforcement arriving after it keeps coming, that the leash
    then runs unchanged (same patience, no further than 2x sight from the post,
    back onto its mark), that a second trip out in the same visit is nothing
    and a new visit gets its own.
  - `test_level_select.gd` - the development floor picker: that switched off
    the character select still goes straight to the game, that the door walk
    finds the whole CHAIN in order with each floor's own title, that the screen
    fits 640x360, backs out by Escape, starts the run on the floor picked and
    then forgets it. It is the one suite that switches the dev setting ON,
    in memory only.
  - `test_release.gd` - the game's half of a release: the menu's footer shows
    the VERSION file, an unpackaged run never asks GitHub, a newer release
    raises the notice while an older, equal, junk or non-GitHub answer does
    not, `1.0.0` beats `1.0.0-rc.1`, and the export presets still ship VERSION,
    still mark the desktop builds `packaged` and still keep the WebRTC plugin -
    and that the architecture each desktop preset exports has a library line
    in the plugin's .gdextension with the file behind it (release.yml then
    looks inside the real builds, tools/release/check_plugin.sh).
    And that a dev build can still be made a different app: the fields
    prepare.sh renames are where it looks for them, and the installer has a
    second `AppId`. And that every scene survives the export packing it
    again: no Control holds anchors off the corner while Godot keeps it in
    POSITION mode, which is how 0.4.0 shipped the boss bar in the top-left
    while every suite, reading the text scene, saw it bottom-centre.
    No network: the answers are handed to the check directly.
  - `test_updater.gd` - the in-game updater (todo.md Parts A and B): the
    switch is off and a feed turns it on, an installed Windows copy may update
    itself and a portable one keeps the link, the right file is picked per
    platform, `SHA256SUMS.txt` parses in both of sha256sum's modes, a hash
    match passes and one changed byte is refused, the release file names
    agree with release.yml and installer.iss, and the panel's states. Nothing
    is downloaded or installed: what would really install is Part D's, on
    real machines. It writes its scratch files under `user://test_updater`
    and removes them.
  - `test_party.gd` - a party of two on one machine: the keyboard drives this
    machine's player and `virtual_input.gd` drives the second. One body per
    member, each its own character, in a row across the marker; the keyboard
    moves only its own and a synthesized press is dated like a key's (a tap
    shorter than a frame still swings); the SECOND player walking out wakes the
    room; an enemy takes the nearest, holds through a near-tie, turns for
    somebody clearly closer and then sticks; offline, no corner ping, notice
    or scoreboard, Tab or no Tab; the second's HUD row and a boss
    counting both heads; a death in company going down with no fade, paying the
    one pool and getting up at the door; the door saying "1/2", then going when
    the one still out in the room goes down, with the body waiting to get up
    getting up on the far side and the overtaken wait doing nothing; and the
    end - the pool empty, a death staying down, and the run over only when
    nobody is standing and nobody is about to be. Its own suite because every
    other one is a party of one, and must stay that way to prove solo did not
    move.
  - `test_watch.gd` - down is a seat in the stands: a party of THREE on one
    machine, because moving the watch on needs two to choose between. Standing,
    the camera is your own; down, it goes to whoever is nearest the fall, says
    WATCHING and the key along the bottom, and really frames them at 400%;
    Space moves it on once per press; the one watched going down moves it on by
    itself, and with one left the key is neither offered nor does anything;
    getting up takes it straight back; and with nobody standing it stays on the
    last fight there was until somebody gets up. Its own suite because a third
    body would renumber every position test_party.gd checks.
  - `test_revive.gd` - picking somebody up (game/revive.gd), a party of two
    on one machine in the lobby, away from HR (whose prompt E also answers).
    Down is lying down - `fall_side`, the solid darker tint, the `fallen`
    group - with an E over the body for the player in reach; holding E roots
    them, turns them to it and keeps their swing, and a green ring fills; half
    full at two seconds, a blow on the one reviving knocks a second off with
    the ring red for it, letting go runs it back down and the E comes back;
    done is up where they lay at 50 with a grace window, turned to the one who
    got them up, `rise` then on their own feet, a green +50, the pool still at
    none - caught on the frame it happens, since what was left to fill decides
    it; a door's wait overtakes a revive in progress and leaves nothing of it;
    and the one down reads "ANAS IS GETTING YOU UP", back to WATCHING when Anas
    lets go. It reads player.gd's constants with `load()` at run time: a
    preload would compile player.gd before the autoloads it names exist.
  - `test_net.gd` - the `Net` autoload: a host and its guests in ONE process,
    each Net in a SubViewport with a MultiplayerAPI of its own, over ENet on
    localhost. Hosting opens a party of one; a guest's hello puts them in it,
    with both ends holding the same roster in the same order (name cleaned,
    character, route) and a ping the host measured reaching the guest; a build
    on another `wire` is refused with `version` and the party never had it;
    START reaches everybody with the same rows; a late arrival is refused with
    `started`; the host leaving is `host_left` at the guest and a guest leaving
    is a row gone at the host; the host's public switch, which a guest cannot
    work; KICK - their seat empty at once and `kicked` at their end, and on a
    LAN free to come back, since there is no service to remember them by; a
    line gone dead both ways (M6) - each end told the other was last heard a
    minute ago, re-told every frame so a ping landing in between cannot undo
    it: a guest ends its party `host_left`, a host drops the guest;
    and the signaling URL, join link and time zone an unpackaged build gets.
    Driven by WAITS with deadlines rather than frame
    numbers, because a connection takes as long as it takes. The online road -
    WebRTC through a signaling service - is the same Net with another peer;
    it is proved by hand against a local `server/signaling`, since a suite
    cannot count on WebRTC finding a route.
  - `test_lobby.gd` - the way into online play through the real screens:
    HOST ONLINE and JOIN ONLINE under PLAY in the four-button height; the
    character select asking the name on the way online; the list of games -
    looking before any answer, the order, every status, the line under it for
    an open, full and started game, the picked game staying picked as the list
    moves and the focus going where a vanished one was; a private game's code
    box (a short code asked again, capitals, the join going with the game's id,
    `wrong_code` keeping the box up, Escape closing only the box); a refusal on
    the line, the server unreachable, nobody hosting, Escape to the menu; then
    the host screen (public by default and remembered, the difficulty stepped
    round and saved) and a room hosted on ENet: a local game has no code and
    no PUBLIC switch, one seat per MAX_PARTY with the host's own marked HOST
    and no KICK; a guest from a SubViewport taking the second seat with KICK
    on it, KICK asking once and going on the second press, the guest told why
    and free to come back on a LAN; the relay line, the code, the join link,
    C copying it, the PUBLIC switch and its line; and START putting the party
    into the game - this machine's body as its own pick, the guest's as
    theirs on still hands, their HUD row by the name they typed - and the
    party ending: the run frozen under the host-left panel naming whoever
    hosted, Escape doing nothing to it and opening no pause menu, and its
    MAIN MENU the way back to a menu that has left the party. Nothing in
    it reaches the internet: the list is handed to Net's `rooms_listed`, a
    join from the list is caught before it leaves, and a relay and a code are
    told to Net directly, which ENet has neither of.
  - `test_coop.gd` - TWO machines in one run (M3), and the first suite that is
    two processes: it hosts, and starts a second Godot (`coop_guest.gd`) that
    joins over ENet on localhost through the real lobby. Two games in one tree
    would share every group, so a SubViewport cannot do it. The harness is
    `tests/coop.gd`: the guest is asked what its machine shows and told what to
    press through `coop_probe.gd`, at /root/CoopProbe in both, which also holds
    both processes to the wall clock so their seconds agree, and what the guest
    prints comes back under `guest|`. It checks the party half: both welcomed
    to one floor and room, each body walking from its owner, a blow, slow,
    shove and heal decided on the host and landing on the guest while the
    guest's own world hurts nobody, down and up on both with one pool, the door
    waiting for both and the guest arriving in the same room, the pause menu
    opening over a running game, the end of the run on both, and the guest's
    body leaving with them. `coop_guest.gd` is not in run_all.gd's list: it is
    a suite's second machine, never a suite.
  - `test_coop_world.gd` - the same two machines, and the ENEMIES: on
    hellfire, which the guest is welcomed to from the lobby, every body the host
    has the guest has where the host has it, a body the host moves moves there,
    a warden winding up on the host fills its field on the guest's screen and
    the slow it lands is the guest's own body's, the guard's blow hurts the
    guest and the guest's swing hurts the guard, a body the host kills is gone
    on the guest, and a reinforcement the host lets in appears there - made
    from the scene its snapshot entry carries - and goes when it dies. Every
    enemy but the one a step is about stands still, so a crowd never decides a
    check.
  - `test_coop_rooms.gd` - the same two machines, and the ROOMS: the studio's
    clock keeping the host's time on the guest and the dolly rolling where the
    host's does; the call floor's wiring on the host's count, Ivan walking in
    on the host and in on the guest with his lines, the hearts he throws there
    landing on the guest's floor, and one the guest walks onto healing the
    guest - decided on the host, gone everywhere; and the hub's scrubbers
    wandering where the host's dice send them. Floors change by the host's own
    travel, since the walk is test_coop.gd's.
  - `test_coop_bosses.gd` - the same two machines, and the BOSSES: Ahmed's bar
    up on the guest by his name, the line he shouts the line the guest reads,
    the fire he throws thrown on the guest's copy of him, the chair he sits in
    staying under him there (an effect that ends with its attack must not find
    the guest a snapshot behind), a shake shaking the guest's camera and his
    stop holding both machines' pictures and neither's clock, his
    health and his concede following; Big Mo going up; Silverman's copy on the
    guest's floor, the prism's fan the one the host measured, and his crossing
    going through the guest's player there too and solid again after. Each boss
    is made to do the thing under test, the way test_ahmed_moves.gd stages a
    move.
  - `test_coop_talk.gd` - the same two machines, and TALKING: a prompt comes up
    only for the player at that keyboard; the guest talks to HR, she is the
    guest's to lead and busy on the host, the host reads her lines along on its
    subtitle, she walks on the host's screen where the guest's machine walks
    her and is the host's again once the guest is done; the host talks to her
    and she is busy on the guest's machine; and a guest who talks Ivan through
    is thrown his hearts by the host, landing on the guest's floor.
  - `test_coop_feel.gd` - the same two machines, and THE FEEL (M4): the host
    draws a walking guest's picture a beat behind its body and back on it once
    it stops, and never a step back on any frame that reaches the screen
    (sampled on `process_frame`, after the network poll); a body the host walks a pixel a frame GLIDES on the guest,
    moving on nearly every frame where twenty snapshots a second would move it
    on one in three; a blow that lands holds the host's picture - its own
    sprite, never the guest's - and never `Engine.time_scale`; the host's blow puts its number up on the guest, its
    swing is heard there off its picture and its impact on its word, and its
    kill breaks apart there; the guest's whole combo is dealt on the host and
    drawn there - numbers over the guard, the arc's bolt, the pieces - with
    its swings and impacts heard, while the host's own picture holds for none
    of it and the guest's holds for all of it; the guest's charge draws its
    ring and its supernova on the host with its hum; and a blow on either
    body is seen, number and grunt, on the other machine. Every staged body
    stands still on the host, and the glider walks through the furniture, so
    the room never decides a check.
  - `test_coop_screen.gd` - the same two machines, and THE CONNECTION ON SCREEN
    (M5): the guest put on the relay in the lobby (`_in_lobby()`, coop.gd's
    hook for arranging a room before START - ENet has no relay, so the host's
    Net is told, as test_lobby.gd does) is told so across the top as the run
    starts and the host is told nothing; the host's corner says HOST and the
    guest's its measured ping; the scoreboard is down until Tab is held and
    down again when it is let go, on each machine by its OWN Tab, with a row
    per player, this machine's marked YOU, HOST and RELAY in the route
    column; and the guest quitting is said across the host's screen by name.
    The host leaving is not here: a guest whose line to the host just went
    cannot be asked anything, so the panel is test_lobby.gd's.
  - `test_coop_cracks.gd` - the same two machines, and THE CRACKS (M6), each
    made to happen on purpose; a LAGGING guest is the probe's `stall`, which
    holds the guest's whole process still - nothing sent, heard or drawn -
    for as long as it is asked. Two press interact by HR on one frame (a
    press is acted on at the start of the next frame and a message sent then
    lands at the other end's next poll, so each machine has begun its own
    before it can hear of the other's - the probe's `talks` counts the
    guest's): one conversation, the host's, the guest's closed again with its
    hands back and HR busy there, and free on both once the host is done. The
    guest's body leaves the doorway and comes back while the host is fading
    through it, and the party still arrives once, in one room. The guest's
    body and then the host's die mid-fade: a life each, up on the far side at
    full health with working hands on both. A guest frozen as the host goes
    through, whose body dies once the host is there: down on both when it
    catches up, up three seconds later. A frozen guest's swing finishes Ahmed:
    he concedes once, bar down on both, and the swings still arriving are
    nothing to him. And the guest's process KILLED with a guard on it: away a
    second later - out of the `player` group, not down, nobody's target and
    untouched - then dropped once the host gives up on the line (the suite
    shortens that with `za/test/drop_seconds`), said across the top, the pool
    untouched, and nothing sent down the dead line after.
  - `test_coop_revive.gd` - the same two machines, a revive each way. The
    host holds E over the guest's body: the host counts, the guest's machine
    draws its own ring filling on the host's word (the probe's `revive`), and
    the guest is up at 50 where it lay on both, with its hands. Then the guest
    holds E over the host's: the host counts off the guest's step alone, a
    blow the host lands on the guest knocks a second off on both machines, and
    the host is up at 50 on both. The pool moves on neither.

## Writing a check

- When synthesizing key events set BOTH `keycode` and `physical_keycode`
  (custom actions match physical, built-in ui_* match keycode).
- **A looping sound proves nothing by having `loop_mode` set.** `AudioStreamWAV`
  seals a loop with `loop_begin`/`loop_end` in FRAMES, and `loop_end` 0 does
  NOT mean "to the end" - a forward loop ending on frame 0 wraps before it has
  played anything, so the playback position stays pinned at 0.000s and the bus
  receives exact silence. Every track and every looping effect in the game
  shipped mute that way while a green check watched `loop_mode`, which was set
  the whole time. The real end is `get_length() * mix_rate` (not `data.size()`
  - these import as QOA, so `data` is compressed bytes rather than frames), and
  the check with teeth is that `get_playback_position()` has MOVED between two
  frames. That works headless: the dummy driver still mixes, so audio is
  testable here rather than something only ears can confirm.
- Level checks read the swapped-in child through `has_method("spawn_position")`
  rather than by class, for the same class-cache reason as game.gd. Leave slack
  around a door transition: two fades plus travel is ~40 frames.
- Anything touching `user://` must put it back. helpers.gd backs up
  `settings.cfg` before each suite, clears it so the run is a clean install,
  and restores it at the end - so running tests never changes how the
  developer's own game opens, and their own saved zoom never decides whether a
  check about framing passes.
- Setting `current_scene` is NOT enough to make `/root/<Autoload>` resolvable;
  it works from `_process`, not from `_initialize`, and the null that comes
  back there fails quietly enough to look like a logic bug.
- `OptionButton.select()` does not emit `item_selected`; simulate a click by
  emitting it too, or the handler never runs.
- Adopt gdUnit4 only once there is real unit-testable logic beyond what the
  suites cover in passing (inventory, save data) - not for scene wiring, which
  is the hard part here and which no framework drives.
