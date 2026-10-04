extends RefCounted
## What Silverman says, and the whole file is data - `game/enemies/enemy_lines.gd`
## is the only thing that reads it, and the only thing that decides when.
##
## He is the name Big Mo passes you up to, and the name on the door: his bar
## reads SILVERMAN and his floor announces itself as SILVERMAN'S OFFICE. What
## he is to the other two nothing in his lines says, on the rule Big Mo's file
## already set: a name is the whole threat, and spelling out the blood turns
## three bosses into a soap opera. Ahmed threatens you with Big Mo, Big Mo
## threatens you with Silverman, and the man at the top of the building
## threatens you with nothing at all.
##
## ## He says everything twice
##
## Swedish first, then the same thing in English, and it is ONE line and ONE
## clip: the `text` below carries both halves with a `\n` between them, so the
## subtitle draws two rows and the recording runs straight through. Nothing in
## `enemy_lines.gd` knows about it. That was the whole test of whether the idea
## was affordable - a second language that needed a second field, a second
## clip or a second timer would have been a rewrite of the shared node for one
## boss, and this is a data file instead.
##
## The saying-it-twice IS the character. He is the one who left, and he came
## back running the place; a man who has spent twenty years in rooms where his
## first language was nobody else's does not assume the room has caught up. It
## reads as courtesy and it costs you the time he is buying with it - which is
## the same trick as everything else he does.
##
## ## He is gracious, and that is the third boss
##
## Ahmed is entitled and loud and sure this is HR's fault. Big Mo is
## procedural, booking the room, noting your feedback. Silverman is PLEASED TO
## MEET YOU - he compliments you, he means it, and he is going to kill you
## anyway. Two men of one family shouting would be one boss fought twice;
## three would be a shame. So there is not one insult in this file, and the
## only thing he ever says about himself is how much time he has.
##
## ## Cues
##
## `boss_base` fires `spot`, `hurt`, `stagger` and `concede`, plus `taunt` when
## the player keeps their distance, plus one named after each attack as it
## winds up - so `glare` and `split` are HIS, off his own attack ids, two where
## Ahmed has four. `meeting` and `review` are his alone, said by `silverman.gd`
## on the frames he crosses into phases two and three: those are DESIGN.md's
## own names for them, and a cue per phase rather than one `herald` cue with
## two lines in it, because which rung of the ladder just arrived is the only
## information in the line and a random pick would throw it away.
##
## The crossing has no cue. It is locomotion that hurts rather than an attack,
## it never runs through `_begin_attack`, and a man who announces his own dash
## is hurrying.
##
## A cue with no entry here is a cue he has nothing to say on, which is legal
## and silent.
##
## ## Two lines of subtitle is a real cost, and the cooldowns are what pay it
##
## Every line here runs about twice as long as one of Ahmed's and stands three
## rows tall on a 360 px screen. The answer is not shorter lines - it is that
## he says fewer of them: his `Lines` child carries a longer `cue_seconds` than
## either of the others and longer still on the two attack cues, so a 0.5 s
## wind-up does not drag a seven-second speech across the fight that follows
## it. Anything added here should be short in BOTH languages for the same
## reason.

## Where his recordings live. A prefix rather than twenty copies of one path:
## a folder spelled out on every line is a folder that cannot be moved.
const VOICE := "res://game/bosses/silverman/sfx/voice/"

const LINES := {
	# He has noticed you. Jumps every queue, so it lands on the frame he
	# looks up whatever else is going on - and what he does with it is say
	# well done, which no other boss in the building would.
	"spot": [
		{"text": "Jag väntade mig inte att du skulle nå hit.\nI did not expect you to reach this floor.",
			"voice": VOICE + "spot_1.wav"},
		{"text": "Elva våningar. Ingen har kommit så långt.\nEleven floors. No one has come this far.",
			"voice": VOICE + "spot_2.wav"},
	],

	# Kept out of his reach and staying there. The one cue that is about the
	# player's behaviour rather than his own - and the only boss in the game
	# who is glad of it. Ahmed roars at a player who runs; this one has the
	# rest of the decade free.
	"taunt": [
		{"text": "Ta din tid. Min kalender är bokad till 2031.\nTake your time. My calendar is booked until 2031.",
			"voice": VOICE + "taunt_1.wav"},
		{"text": "Tålamod är inte att vänta. Det är att veta.\nPatience is not waiting. It is knowing.",
			"voice": VOICE + "taunt_2.wav"},
		{"text": "Du är stark. Det räcker sällan.\nYou are strong. That is rarely enough.",
			"voice": VOICE + "taunt_3.wav"},
		{"text": "Alla som stått där du står blev erbjudna en stol.\nEveryone who stood where you stand was offered a chair.",
			"voice": VOICE + "taunt_4.wav"},
		{"text": "Ett rum vinner man med lugn.\nA room is won by staying calm in it.",
			"voice": VOICE + "taunt_5.wav"},
		{"text": "Jag byggde det här huset. Jag har inte bråttom.\nI built this building. I am not in a hurry.",
			"voice": VOICE + "taunt_6.wav"},
	],

	# One per attack, said on the wind-up - so the shout is part of the
	# telegraph rather than a comment on it. Both are short on purpose: a
	# telegraph that outlasts its own attack has stopped being one.
	"glare": [
		{"text": "Se på mig.\nLook at me.", "voice": VOICE + "glare_1.wav"},
		{"text": "Ljuset är mitt.\nThe light is mine.",
			"voice": VOICE + "glare_2.wav"},
	],
	"split": [
		{"text": "Delegering.\nDelegation.", "voice": VOICE + "split_1.wav"},
		{"text": "Jag skalar upp.\nI am scaling up.",
			"voice": VOICE + "split_2.wav"},
	],
	# The glass ceiling, the line it was previewed with: said as he looks up,
	# and the top floor of the ladder is the one place it is simply true.
	"ceiling": [
		{"text": "Det finns ett tak.\nThere is a ceiling.",
			"voice": VOICE + "ceiling_1.wav"},
	],

	# The ladder, announced. One line each for the same reason `concede` has
	# one: there is no second thing to say when a phase arrives, and the name
	# of the phase IS the line.
	"meeting": [
		{"text": "Mötet börjar nu.\nThe meeting begins now.",
			"voice": VOICE + "meeting_1.wav"},
	],
	"review": [
		{"text": "Dags för utvecklingssamtal.\nTime for your performance review.",
			"voice": VOICE + "review_1.wav"},
	],

	# Being hit is FEEDBACK. He is the only boss who thanks you for it, and
	# the third line is the only place the family is ever mentioned by a man
	# who outranks all of it.
	"hurt": [
		{"text": "Bra. Notera det.\nGood. Note that down.",
			"voice": VOICE + "hurt_1.wav"},
		{"text": "Du lär dig fort.\nYou learn quickly.",
			"voice": VOICE + "hurt_2.wav"},
		{"text": "Ahmed slog aldrig så hårt.\nAhmed never hit that hard.",
			"voice": VOICE + "hurt_3.wav"},
	],

	# An interrupt. He is not hurt, he is CORRECTED - and being corrected is
	# rare enough up here to be worth remarking on.
	"stagger": [
		{"text": "Intressant.\nInteresting.", "voice": VOICE + "stagger_1.wav"},
		{"text": "Du avbröt mig. Få gör det.\nYou interrupted me. Few do.",
			"voice": VOICE + "stagger_2.wav"},
	],

	# The end, and the last line of the last fight in the game. Alone in its
	# cue on purpose: jumping the queue is what makes sure it is the last
	# thing heard, and it is the compliment paid in full - the job was never
	# the thing being fought over.
	"concede": [
		{"text": "Du har jobbet. Det har du haft hela tiden.\nYou have the job. You always did.",
			"voice": VOICE + "concede_1.wav"},
	],
}
