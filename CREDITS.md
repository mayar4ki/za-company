# Third-party assets

## Top-down character, dungeon tileset, jar
- Author: **profpatonildo**
- Source: https://opengameart.org/content/pixel-art-top-down-dungeon-tileset-and-rpg-character-with-animations
- License: **CC0 1.0 Universal** (public domain) - no attribution required, commercial use permitted
- Files: `game/player/src/character_cc0.png`, `game/enemies/src/body_cc0.png`
  (an identical frozen copy of it), `assets/tiles/dungeon.png`,
  `assets/props/jar/jar.png`
- Editable Aseprite sources kept alongside in `game/player/src/`, `assets/props/jar/src/` and `assets/tiles/src/`
- Every playable character (`game/player/characters/*_frames.tres`) is a
  **restyle** of that sheet, not the original: recoloured hair, skin, eyes and
  clothes per character. `tools/build_characters.gd` regenerates them from
  `game/player/src/character_cc0.png`, which is the cast's working sheet and
  will grow animations over time.
- The project icon (`icon.svg`) is the default character's restyled idle frame
  from that sheet, framed in code by `tools/build_icon.gd`; the round frame,
  the green band and its lettering are original work.
- Every enemy sheet (`game/enemies/<id>/src/<id>.png`) was **seeded** as a
  restyle of `game/enemies/src/body_cc0.png` - a byte-identical, deliberately
  frozen copy of the same CC0 sheet - and is hand-owned art from then on. The
  copy exists so that seeding stays reproducible while the cast's sheet changes
  underneath it. Both are CC0, so copying and restyling is unrestricted.
- The marble and hellfire tilesets are derived from `dungeon.png`: floor and
  wall tiles are palette-swapped copies of it (see `tools/build_biomes.gd`).
  CC0 permits this without restriction. The columns and door arches in those
  same files are original work, not derived from the sheet.
- Every office floor's tileset is derived the same way. Everything else in
  those rooms is original work with no third-party source: the glazed pillar,
  the cubicle divider, and the four office hazards - the sparking floor
  polisher, the arcing power strip, the fallen ring light and the jammed
  copier (`tools/props/fixtures/`) - plus the office furniture, the
  maintenance floor's hardware and junk, the call floor's phones and its lit
  wallboard, the media team's glass partitioning, edit bays, ring lights and
  paper backdrop, the gym's punch bags, weight racks and the boxing ring
  painted on its floor, the innovation lab's workstations, coffee machine,
  whiteboard diagram and build board, the executive floor's awards cabinets,
  boardroom table, drinks trolley, founder's portrait and rug, the penthouse's
  city window, its one bare desk and the note lying face down on it, the signs
  and the neon, and the 5x5 pixel font (`tools/props/`) - all drawn in code,
  since the dungeon sheet has no furniture or hardware in it to derive from.
- `game/enemies/office_boy/src/office_boy.png` was seeded as a restyle of the
  frozen CC0 body like every other enemy sheet, and is hand-owned from now on.
- `game/npcs/dominique/src/dominique.png` and `game/npcs/ivan/src/ivan.png`
  were seeded from the same CC0 cast sheet and then rebuilt at double height
  in a robe by `tools/npc_art.gd` - the robe, the hem, the waist cord and the
  doubled head are drawn in code, not sampled from anything. 64px cells, and
  hand-owned art from the moment they were written.

Credited voluntarily; CC0 imposes no obligation to do so.

## UI fonts
- Author: **Kenney** (https://kenney.nl)
- Source: https://kenney.nl/assets/kenney-fonts
- License: **CC0 1.0 Universal** - "free to use in personal, educational and
  commercial projects", crediting requested but explicitly not mandatory
- Files: `assets/fonts/KenneyBlocks.ttf` (titles), `assets/fonts/KenneyMiniSquare.ttf` (UI),
  plus `KenneyPixel.ttf` and `KenneyFutureNarrow.ttf` kept as alternatives

## Ahmed's and Big Mo's sound effects
- Author: **generated with ElevenLabs** (text-to-sound-effects), then trimmed,
  summed to mono, levelled and loop-sealed by hand
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0 like everything above, which is why they are listed separately
- Files: `game/bosses/big_mo/sfx/*.wav` - eleven: a telegraph and an impact
  for each of jab, hook and rush, the `rage` eruption, the `fire` loop he wears
  from half health on, and his hurt/stagger/concede. And
  `game/bosses/ahmed/sfx/*.wav` - the burning axe's idle loop, his hurt
  grunt, the stagger that says an interrupt landed, the axe hitting the floor
  as he concedes, and the breathing he is left with; plus the eight attack
  sounds, a `<attack>_windup` telegraph and a `<attack>_hit` impact for each of
  chop, sweep, slam and wave
- Big Mo's twenty-two voice lines are Eleven v3 text-to-speech (voice
  "Edward"), cut by `tools/voice/cut.py big_mo`; Ahmed's twenty-three are the
  same pipeline on voice "Jack". Both are delivery-tagged per cue rather than
  steered by a stability slider - the tags live in `tools/voice/<boss>.py`
  beside the rest of the recipe, and what each boss SAYS lives with him in
  `taunts.gd`
- The eight were generated through the Sound Effects API rather than the web
  app (`POST /v1/sound-generation`, `output_format=pcm_48000`), which is worth
  knowing for the next batch: it returns raw STEREO 16-bit PCM with no WAV
  header and no leading padding, so the header is written by hand, the two
  channels are summed to mono, and only the dead TAIL needs trimming. The
  prompts, durations and levelling are `tools/`-free on purpose - they live in
  the scratchpad script that made them, and the files below are the artefact
- The untouched ElevenLabs exports are kept in `game/bosses/ahmed/src/`
  beside his sheet, on the same terms as `assets/music/src/` and every other
  `src/` here: the original is hand-owned and never played, the file above it
  is what the game loads. Re-trimming one therefore costs no credits.
- What the game plays is 48 kHz mono 16-bit WAV, levelled against each other
  rather than all normalised to full scale: the idle fire sits at -14 dBFS because it
  plays for the whole fight, and the one-shots sit near -4 so a hit reads over
  it. Re-generating one means re-levelling it to match, not just dropping the
  new file in.
- The attack sounds keep that rule and add one of their own: impacts join the
  one-shots at -4 dBFS, and **telegraphs sit at -9**. A wind-up as loud as the
  blow it warns about has stopped being a warning. Each telegraph is also
  shorter than the wind-up it plays under - the tightest is `sweep_windup` at
  0.48 s against a 0.52 s wind-up - so a swing never lands while its own
  warning is still going.

## The player's sound effects
- Author: **generated with ElevenLabs** (text-to-sound-effects), then trimmed,
  summed to mono, levelled and loop-sealed by `tools/sfx/make.py`
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0 like the art, on the same footing as every other sound here
- Files: `game/player/sfx/*.wav` - eight. `swing` and `swing2` for the two
  light attacks, `charge` for the stance, `heavy` and `wildfire` for the spin
  and the ring of fire it erupts into, `hit` for a blow that lands, `hurt` for
  one taken, and `die`
- **One set for all seven characters**, which is the cast's sheet rule applied
  to the other sense: they share one body and one animation set forever, so a
  swing cut once has to land on all of them. Its one consequence is designed
  for rather than discovered - `hurt` and `die` are asked for breathy and
  neutral in pitch, because six of the seven are not whoever a gendered grunt
  would sound like
- The recipe is in the repo beside the bestiary's: `tools/sfx/player.py` holds
  the prompts, durations and levels, `make.py` the mechanism. Both are read by
  the same engine, which is why its recipe dict is `CAST` rather than `ENEMIES`
- The untouched exports are kept in `game/player/src/sfx/`, on the same terms
  as every other `src/` here, so re-shaping costs no credits
- Levelled ABOVE the bosses and the enemies rather than under them, and it is
  the same arithmetic upside down: a room holds seven enemies and one player,
  so the sound that says YOU are losing is the one that must never be won by a
  crowd. `hurt` and `die` at -19 dBFS RMS, level with a boss's blow; `swing` at
  -27, because it is the most-heard sound in the game

## The enemies' sound effects
- Author: **generated with ElevenLabs** (text-to-sound-effects), then trimmed,
  summed to mono, levelled and loop-sealed by `tools/sfx/make.py`
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0 like the art above, on the same footing as the bosses' sounds
- Files: `game/enemies/<id>/sfx/*.wav` - twenty-six across six enemies. The
  four that run the attack cycle (`regular`, `office_boy`, `warden`,
  `call_center`) get five each - `windup`, `hit`, `hurt`, `stagger`, `die`;
  the two drainers (`wraith`, `social_media`) get three - `drain`, `hurt`,
  `die` - because they opt out of the cycle and so have no wind-up to
  telegraph, no blow to land and nothing to stagger
- **Every enemy has its own**, including each reskin, on the same terms as its
  sheet: `office_boy` is mechanically the regular to the frame and sounds
  nothing like it, because he thrusts a wrench where the guard swings a sword
- **The recipe is in the repo**, which the bosses' sound effects above are the
  one exception to: `tools/sfx/` holds the mechanism (`make.py`, plus the
  audio kit in `wav.py`) and the prompts, durations and levels
  (`enemies.py`). Re-generating one is one command; re-SHAPING one is
  `--relevel` and costs nothing
- The untouched exports are kept in `game/enemies/<id>/src/sfx/`, on the same
  terms as `assets/music/src/` and every other `src/` here: the original is
  hand-owned and never played, the file above it is what the game loads.
  Re-trimming therefore costs no credits
- What the game plays is 48 kHz mono 16-bit WAV, levelled against each other
  AND against the bosses rather than normalised to full scale. A boss floor
  holds one boss; hellfire holds four guards, two wraiths and a warden, so the
  enemies sit under him: impacts at -22 dBFS RMS against his -19, telegraphs
  at -29 (7 dB under their own impact, his ratio), grunts at -24, deaths at
  -22, and the wraith's continuous drain loop at -30. Re-generating one means
  re-levelling it to match, not just dropping the new file in
- Peaks are held under -3 dBFS by a soft limiter (tanh at the ceiling) rather
  than a gain cut, which is the lesson Ahmed's slam paid for: pulling a whole
  sound down so its tallest transient fits is what holds an impact under
  target in the first place
- The two `drain` loops are the only looping files here, and each was
  generated at 8 s so the steadiest 2.5 s could be CHOSEN out of it, then
  crossfaded 12 ms tail-over-head. Both fixes are needed and neither is
  visible without the other: the model writes a beginning and an end even when
  asked not to, and a raw export ends mid-waveform and clicks once per pass

## The enemies' mutters
- Author: **generated with ElevenLabs** (text-to-speech, Eleven v3), then
  trimmed and levelled by `tools/voice/cut.py`
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0, on the same footing as every other generated sound here. A
  synthetic voice also carries the terms of the VOICE used, which is a
  separate question from the audio; check both before the game ships
- Files: `game/enemies/social_media/sfx/voice/*.wav` (8) and
  `game/enemies/call_center/sfx/voice/*.wav` (8) - one cue, `mutter`, named
  `mutter_<n>.wav`, one per line in that enemy's own `mutters.gd`
- Voices: **Laura** (`FGY2WhTYpPnrIDTdsKH5`, female) for the Content Studio,
  **Eric** (`cjVigY5qzO86Huf0OWal`, male) for the phone team. Neither is a
  voice on the account's own list. Ahmed is Jack and Big Mo is Edward; no two
  characters in this game may share a voice, which is the whole point of a
  bestiary that talks
- **The recipe is in the repo**: `tools/voice/` holds the mechanism (`cut.py`,
  unchanged - it never cared whether the mouth had a health bar) and each
  one's direction (`social_media.py`, `call_center.py`). WHAT they say lives
  with them in `game/enemies/<id>/mutters.gd` and is read from there, so no
  line is written down twice
- The untouched exports are kept in `game/enemies/<id>/src/voice/`, beside but
  never inside `src/sfx/`, so a re-cut of a voice can never overwrite a sound
  effect. Re-trimming costs no credits
- Levelled to **-31 dBFS RMS**, twelve under the bosses' -19 and below the
  warden's own telegraph at -29: a wind-up is information the player needs and
  a mutter is decoration, so it must never be the louder of the two. Voice
  carries at a lower RMS than a noise effect because it occupies a band
  nothing else here does
- Every clip was transcribed back with `cut.py <id> --verify` and compared to
  the line it was cut from, which is the check that catches Eleven v3 READING
  a delivery tag aloud instead of acting on it - inaudible in a waveform,
  obvious in a fight. All sixteen say their line

## Ahmed's voice
- Author: **generated with ElevenLabs** (text-to-speech, Eleven v3), then
  trimmed and levelled by `tools/voice/cut.py`
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0, on the same footing as the sound effects above. A synthetic
  voice also carries the terms of the VOICE used, which is a separate question
  from the audio: this one is `EtsjFhqOd0YWASYxlmIg`, and it is not a voice on
  the account's own list, so check its licence before the game ships.
- Files: `game/bosses/ahmed/sfx/voice/*.wav` - twenty-three lines, one per
  thing he says in `game/bosses/ahmed/taunts.gd`, named `<cue>_<n>.wav`
- **The recipe is in the repo**, unlike the sound effects above: `tools/voice/`
  holds the mechanism (`cut.py`) and Ahmed's own direction (`ahmed.py`, a
  delivery tag per cue). Re-cutting a reworded line is one command. Two clips
  are pinned in that file as approved takes and are never re-cut, because
  text-to-speech is not deterministic and re-running would quietly ship a
  performance nobody chose.
- Same format as his grunts - 48 kHz mono 16-bit - fetched as
  `output_format=pcm_48000` and given a WAV header directly, so there is no MP3
  stage and no encoder to install. Levelled on the **75th percentile of speech**
  rather than on peaks, to -19 dBFS, which is where his grunts already sit; peak
  matching had left a roar and a mutter 13 dB apart in the only thing anybody
  hears.
- `cut.py --verify` transcribes every clip back and compares it to the line it
  was cut from, which is the one check that catches a delivery tag being read
  ALOUD instead of acted on - inaudible in a waveform, obvious in a fight.

## Silverman's voice and his sound
- Author: **generated with ElevenLabs** - his voice by text-to-speech (Eleven
  v3), trimmed and levelled by `tools/voice/cut.py`; his one sound effect by
  text-to-sound-effects, shaped by `tools/sfx/make.py`
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0, on the same footing as Ahmed's above. The voice is
  `x0u3EW21dbrORJzOq1m9` (Adam Composer, a Swedish voice), and its own terms
  are a separate question from the audio's: check them before the game ships.
- Files: `game/bosses/silverman/sfx/voice/*.wav` - twenty-one lines, one per
  thing he says in `game/bosses/silverman/taunts.gd`, each said twice in one
  clip (Swedish, then English), named `<cue>_<n>.wav`; and
  `game/bosses/silverman/sfx/ceiling_crash.wav`, the glass ceiling landing
- The recipes are in the repo: `tools/voice/silverman.py` (a delivery tag per
  cue) and `tools/sfx/bosses.py` (the crash's prompt, length and level). The
  untouched exports are kept in `game/bosses/silverman/src/voice/` and
  `src/sfx/`, so re-levelling costs no credits
- Levelled like the others: the voice to -19 dBFS on the 75th percentile of
  speech, the crash to -17 RMS. The glass ceiling's line and crash were each
  picked from several takes auditioned over the live attack, and are pinned in
  their recipes' `KEEP`

## HR's voice
- Author: **generated with ElevenLabs** (text-to-speech, Eleven v3), then
  trimmed and levelled by `tools/voice/cut.py`, exactly as Ahmed's are
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0, on the same footing as every other generated sound here. The
  VOICE carries its own terms separately from the audio: this one is
  `ogwqBH5bbF03DSbNiRNN`, and its licence wants checking before the game ships.
- Files: `game/npcs/hr_lady/sfx/voice/*.wav` - twenty-three clips for the
  twenty-four lines she speaks in `game/npcs/hr_lady/welcome.gd`. The
  twenty-fourth is not missing: her first and third refusals are the same five
  words, and they deliberately share one recording, because a woman repeating
  herself in the *identical* take is the joke that two performances of it would
  soften.
- **Named by the beat, not by a number.** Ahmed's clips are `<cue>_<n>.wav`,
  derived from the fight. Hers are read back out of the `voice` path each beat
  already carries for the game to load, so writing a new line into the middle
  of the induction does not renumber - or re-bill - the twenty after it.
- What stays unvoiced is the player. The contract branch has them answering
  her, and those beats carry no clip on purpose: the player is silent
  everywhere else in this game.
- Ten delivery tags across the twenty-three, shared the way Ahmed's swings
  share one read, and the arc is the content: bright through the tour, sweetly
  insistent through the first refusals, and flat by the third. Her whole joke is
  that the menace is never in the words, so it has to be in the read.
- Levelled to -19 dBFS on the 75th percentile of speech, the same number Ahmed
  sits at - one figure across every mouth in the game, since a file's own level
  IS the mix here and there is no bus layout.
- `cut.py --verify` is green on all twenty-three. Four `SPELLINGS` entries are
  needed to keep it that way and none of them is a bad take: scribe writes
  "8:59" back as three words and "Eleven" as digits, and it is not deterministic
  either - the same clip read back clean on one pass and showed a homophone
  ("council" for "counsel") on the next. Transcribing a take twice and getting
  two answers is the give-away that the difference is in the listener.

## Ivan's voice
- Author: **generated with ElevenLabs** (text-to-speech, Eleven v3), then
  trimmed and levelled by `tools/voice/cut.py`, exactly as Ahmed's and HR's are
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0, on the same footing as every other generated sound here. The
  VOICE carries its own terms separately from the audio: this one is
  `XaEUesE01wKIKaa0xI0h`, and it comes from the shared library rather than the
  account's own list, so its licence wants checking before the game ships.
- Files: `game/npcs/ivan/sfx/voice/*.wav` - eighteen clips, three for each of
  the six floors he arrives on, named by the beat the way HR's and Dominique's
  are (`call_eat`, `ahmed_salt`, `gym_ring`) rather than numbered. The names are
  namespaced by floor because all six conversations cut into one folder and
  nothing dedupes across them - every floor ends on the same word, so two files
  calling that clip `eat` is a mistake waiting rather than a hypothetical
- **An English read with an Eastern-European accent**, which is the whole of the
  brief and the one thing worth auditioning rather than picking: four voices
  were cut on his last line and compared side by side before this one was
  chosen. What carries forward from that audition is the VOICE ID above; the
  take itself was a performance of a line that no longer exists, since his three
  shared lines became eighteen per-floor ones, and it went with the file it was
  in. Every clip now has its untouched export in `src/` and re-levels for free.
- Five delivery tags across eighteen lines, shared the way HR's ten are: the arc
  inside a floor is the same three steps every time - arrive gruff, be fond
  about a colleague, land the food warm - which is what makes six visits sound
  like one man with a routine. The executive floor is the one exception, quiet
  and then hurried, because it is the only room he is frightened of being seen
  in.
- Levelled to -19 dBFS on the 75th percentile of speech, the same figure as
  every other mouth in the game.
- `cut.py --verify` is green on all eighteen, over a `SPELLINGS` table of three
  transcriber habits - a contraction, a digit for a spoken number, and a
  transliterated name. Three takes that had actually caught a WRONG word ("I ran
  the kitchen" for "I run") were re-cut instead of being spelled away, which is
  the line that table is not allowed to cross.

## Dominique's voice
- Author: **generated with ElevenLabs** (text-to-speech, Eleven v3), then
  trimmed and levelled by `tools/voice/cut.py`, exactly as the other three are
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0, on the same footing as every other generated sound here. The
  VOICE carries its own terms separately from the audio: this one is
  `Xh5OictnmgRO4dff7pLm`, from the shared library rather than the account's own
  list, so its licence wants checking before the game ships.
- Files: `game/npcs/dominique/sfx/voice/*.wav` - twelve clips for the twelve
  lines across the three briefings in `game/npcs/dominique/before_<boss>.gd`
- **One voice, three conversations, one folder**, which is the only thing about
  this mouth that is not HR's arrangement exactly: `BEATS` in the recipe is a
  LIST. Nothing dedupes clip names across files, so the names are namespaced by
  the boss they warn about (`ahmed_`, `big_mo_`, `silverman_`) - two briefings
  sharing a name would cut once and one floor would quietly play the other
  floor's warning. `tests/test_dominique.gd` checks that no two floors share a
  clip, because cut.py would not have said anything.
- **Bold, Slavic and impatient**, picked off the same four-voice audition Ivan's
  read came out of and deliberately not his warmth: Ivan is glad to see you, and
  Dominique has given this speech before to people who did not come back.
- Four delivery tags across the twelve, shared the way HR's ten are, and the
  arc inside each briefing is the same three steps - open brisk, state the
  fight flat, land the tell hard.
- Levelled to -19 dBFS on the 75th percentile of speech, the same figure as
  every other mouth in the game.
- `cut.py --verify` is green on all twelve. Three `SPELLINGS` entries are
  needed and none of them is a bad take: scribe contracts where the line does
  not ("you're"), writes the American spelling of a word with one pronunciation
  ("ax"), and picks its own transliteration of a name ("Mustafa"). Each was
  listened to before it was written down - a spelling entry is how a take is
  forgiven, so it must never be how a bad one is hidden.

## Music
- Author: **generated with ElevenLabs** (text-to-music)
- License: per the ElevenLabs terms in force for the generating account -
  **not** CC0 like the art above, on the same footing as the sound effects
- Files: `assets/music/finale_loop.wav` (the last two floors - the executive
  floor and the penthouse, which share it so the music crosses the door between
  them unbroken; dark cyberpunk / industrial darksynth, 120 BPM read as
  half-time, which is the same grid Big Mo's sits on and therefore Silverman's
  0.5 s wind-up on the beat rather than drifting against it),
  `assets/music/menu_loop.wav` (the front end),
  `assets/music/level_loop.wav` (the bed under the nine floors that name no
  track of their own - see below), `assets/music/lobby_loop.wav` (floor 1
  alone, which was the bed until the building got a faster one), `assets/music/ahmed_theme_loop.wav` (Ahmed's fight, floor 4)
  and `assets/music/big_mo_theme_loop.wav` (Big Mo's, the gym on floor 7 -
  industrial cyberpunk techno at 120 BPM, which is a beat every 30 frames and
  therefore his 0.25 s jab on the grid rather than drifting against it)
- **The finale's numbers**, since every one of them was measured rather than
  chosen: the export ran 60.000 s at a true 119.9975 BPM, cut back to 28 whole
  bars at **56.0011 s** - the bar count picking which peak, and a low-band
  sweep saying where it is (+55 samples off the nominal 56.000, r +0.86) - then
  the usual 12 ms equal-power crossfade, then **-5.24 dB** to land on
  `big_mo_theme_loop`'s -16.24 dBFS RMS. That last number is the one that
  looks wrong and is not: this track plays over an ORDINARY floor as well as a
  boss arena, so it sits above the enemies whose telegraphs are levelled at -29
  rather than above nothing, and matching the other techno track in the game is
  matching the one whose kick lives in the same band. Peak lands at -5.81
  dBFS, so no limiting was needed.
- These live in `assets/` rather than in the feature that plays them, which is
  the one place that rule bends: `menu_loop` is asked for by three front-end
  screens and belongs to none of them, and keeping the tracks in one folder
  is what makes them levellable against each other at a glance. Who plays a
  track is said on the boss instead - see game/bosses/CLAUDE.md.
- 48 kHz 16-bit stereo, and deliberately stereo where the sound effects are
  mono: an effect is positional and pans with the room, a track is not standing
  anywhere. All three are trimmed by `Music.VOLUME_DB` (-8) rather than
  normalised, and Ahmed's sits ~1.5 dB hotter than the menu's at source, which
  is the right direction - a fight should be more present than a menu bed.
  **A boss theme is levelled against his own sounds, not against the other
  theme**, and Big Mo is where that was learned. Matching Ahmed's RMS came
  first (-1.7 dB, since his export landed that much hotter) and it was the
  wrong target: broadband loudness says nothing about MASKING, which is per
  band. Measured in octave bands at playing level, his eruption `rage.wav`
  cleared the bed by 3.9 dB at best and his `fire` loop by 0.1, because both
  live under 250 Hz and that is exactly where a techno track keeps its kick
  (60-125 Hz sits 17 dB above its own mids). Ahmed's quietest sound clears his
  theme by 2.3 dB, so that is the floor this was levelled to: a further -3 dB,
  i.e. **-4.67 dB flat from the export**, which puts every one of Big Mo's
  eleven sounds at least 3.1 dB over the bed in some band, with the hook - the
  one read in the fight - at 20.5. He therefore sits 3 dB under Ahmed at
  -16.1 dBFS RMS, peak -5.2, and that is the number doing a job rather than a
  mismatch.
- **`level_loop.wav` is the bed, and it is the one export that arrived
  already loopable.** Driving cyberpunk synthwave at **128.00 BPM** - four on
  the floor, off-beat 16th hats, a detuned saw bassline - and the reason it
  came back clean is the ASK rather than luck: it was asked for as a single
  continuous **32-bar** groove at constant intensity, no intro, no build, no
  drop, no fade, last bar as loud and as busy as the first. 32 bars at 128 BPM
  is 60.000 s, which is exactly what ElevenLabs exports, so there was nowhere
  to put an ending. It has neither of the two failures the tracks below have:
  the last 8 s alternate +2.0 / -2.3 dB about the body, on-beat against
  off-beat, right to 59.75 s, and a low-band sweep put the grid at 128.00 BPM
  to within a millisecond over 30 bars. So nothing was cut back to a bar line -
  the whole file WAS the loop - and only the usual 12 ms equal-power crossfade
  was needed, taking the seam step from **39526 of 32768 to 706**, which is
  this track's own mean sample-to-sample step. 59.988 s, 2,879,424 frames.
- **And then it came down 6.5 dB, which is the part that was not optional.**
  The export sits at -12.80 dBFS RMS: louder than the menu, louder than
  Big Mo, louder than Ahmed - i.e. the bed under nine ordinary floors would
  have been the loudest thing in the game, and walking onto a boss floor would
  have read as the music getting SMALLER. It is levelled **-6.48 dB to
  -19.28 dBFS RMS**, peak -7.35, which is the number the previous bed sat at
  and therefore the number every masking figure below was measured against -
  including HR's -19 dBFS speech level in the lobby. Excitement here is the
  tempo and the arrangement, not the fader. Post-gain the seam step is 335
  against a mean step of 367, so the join stays under the music's own motion.
- **`lobby_loop.wav` is floor 1's, and was the bed.** Calm cyberpunk ambience
  at 90 BPM - deliberately NOT Big Mo's grid. It was written as the bed, on
  the brief "cyberpunk, but calmer", and it is now the tutorial floor's alone:
  the lobby is where a player is still finding out which key swings, and a
  track that insists on a pace is a track arguing with the room. A beat is 40
  frames at 60 fps, so it is still a whole number of them. It is levelled to
  **-19.28 dBFS RMS, which is the level the previous bed sat at**, and that is
  a target rather than a coincidence: everything below about masking was
  measured against that number, so matching it is what lets a track be swapped
  without re-deriving the paragraph. It stays the quietest of the four by some
  way, and the bed that replaced it is levelled to the same number for the
  same reason - 4.7 dB under the menu, 6.2 under Ahmed and 3.2 under Big Mo. That gap is the point rather than an accident, and it is
  doing two jobs. It is the escalation - walking onto a boss floor has to read
  as the music getting bigger - and it is the headroom, because this is the
  track that will still be playing when ordinary floors finally get sound
  effects of their own. There is now one thing to measure it against, and it is
  the loudest thing an ordinary floor is ever likely to carry: **HR's voice**,
  in the lobby, at -19 dBFS speech level. That is 0.4 dB over this track's own
  RMS, so a line of hers and this bed are within half a decibel of each other -
  which is exactly the case the masking arithmetic above was written for, and
  the first place to listen if her induction ever sounds like it is competing
  with the room rather than being said in it.
- Untouched exports go in `assets/music/src/` on the same terms as every other
  `src/` here. `menu_loop`, `big_mo_theme_loop`, `lobby_loop` and
  `level_loop` have one;
  `ahmed_theme_loop` is currently played as it came out of the generator, so
  re-trimming its loop seam means keeping a copy there first.
- **`lobby_loop` needed the cut before it could take the crossfade at all,
  and it needed it TWICE** - the track was regenerated to a calmer brief and
  the replacement export ends exactly the way the first one did. The last
  2.6 s fades away to -85 dBFS while the head starts cold at full level, so as
  a loop it died once a minute rather than clicking. The music is intact to
  57.35 s and it is cut to **53.322 s, 20 bars**, with 12 ms of what is left
  over crossfaded back over the head. The seam step goes from 452/271 to 3/3
  against a largest body step of 571, i.e. from audible to 190x below the
  music's own motion. 2,559,472 frames.
- **Cut on the track's OWN grid, not on the one you asked for**, which is what
  the second cut taught and the first one got away with. This export was asked
  for at 90 BPM and delivers 90.019 - inaudible as tempo, and 11 ms of drift by
  the twentieth bar, which is longer than the whole crossfade. Cutting at the
  nominal 53.333 s took the tail-against-head correlation from 0.875 to -0.12:
  the match at a loop point is WAVEFORM PHASE, not bar arithmetic, so it is
  sharp at the millisecond and a cut that is musically right to the ear can
  still comb-filter against the head. The measurement that finds it is the
  tail's last second correlated against the head's first, swept at sample
  resolution near the bar you want; the bar count is how you pick which peak,
  not where it is. Its cost is that the played period is 11 ms short of 20 whole
  bars - which nothing can hear and nothing syncs to, since the bed is the one
  track no fight is timed against.
- **Big Mo's loop is sealed, Ahmed's is not**, and the numbers say why it
  matters: the step across the loop point was 9139 against a median
  sample-to-sample step of 591 in the body, i.e. a tick once a minute, and a
  12 ms equal-power crossfade of the tail over the head takes it to 19 for
  0.012 s of length. Ahmed's seam is 10413 against a body step of 125 and is
  the louder of the two - a known debt, and the same fix when it is paid.

## WebRTC for desktop (online co-op)
- **Not an asset and not CC0**: the first third-party CODE in the project, so
  its licences carry obligations the art's do not.
- Project: **webrtc-native** 1.2.2-stable by the Godot Engine contributors,
  the official GDExtension that gives desktop Godot `WebRTCPeerConnection`
- Source: https://github.com/godotengine/webrtc-native/releases/tag/1.2.2-stable
- Files: `addons/webrtc_native/`, vendored from the release zip with only the
  desktop libraries kept (Windows and Linux x86_64, macOS universal; debug and
  release of each). `webrtc_native.gdextension` is untouched, so it still
  lists the other platforms; restore their libraries from the same zip before
  exporting for one.
- Licences, each shipped beside the libraries as `LICENSE.<name>`:
  webrtc-native **MIT**; libdatachannel and libjuice **MPL-2.0**; usrsctp and
  libsrtp **BSD-3-Clause**; Mbed TLS **Apache-2.0** (dual-licensed, Apache
  taken); plog **MIT**.
- What that asks of a release: keep the licence files with the shipped
  binaries, and since MPL-2.0 covers libdatachannel and libjuice, say where
  their source is (https://github.com/paullouisageneau/libdatachannel and
  https://github.com/paullouisageneau/libjuice) in the game's credits or
  readme. The game's own code is unaffected - MPL is per file.

## Windows installer
- Built with **Inno Setup** by Jordan Russell and Martijn Laan
  (https://jrsoftware.org/isinfo.php), from `tools/release/installer.iss`, on
  GitHub's build machines - nothing of it is in the repository.
- Licence: the Inno Setup License, a modified BSD-style licence that permits
  distributing installers made with it, commercially included. Each
  `*-windows-setup.exe` contains Inno Setup's own setup code, so it is a
  credit owed by every release, not only by the repository.
