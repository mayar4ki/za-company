extends Node2D
## The small E over a body that is down, on the machine whose player is close
## enough to revive it and while nobody is - the key you hold, said where you
## are looking. The Revive Lab preview's `drawPrompt`, drawn the way the page
## drew it: a 9 px dark key with a pale bottom edge and the E in the damage
## numbers' 3x5 hand. game/revive.gd owns the one there is, and moves it from
## body to body or hides it every frame; `top_level`, so it is placed in the
## world wherever it hangs in the tree.

const KEY := Color(20 / 255.0, 18 / 255.0, 28 / 255.0, 0.85)
const KEY_EDGE := Color(1.0, 1.0, 1.0, 0.6)
const INK := Color.WHITE
const OUTLINE := Color(20 / 255.0, 18 / 255.0, 28 / 255.0)
const E := "111100111100111"
## The key's top-left corner from the body's feet: the page's (q.x - 4, q.y - 22).
const FROM_FEET := Vector2(-4.0, -22.0)
const Z := 50


func _ready() -> void:
	top_level = true
	z_index = Z


## Over `body`'s feet, or hidden with null.
func over(body: Node2D) -> void:
	visible = body != null
	if body != null:
		var at := (body.call("drawn_at") as Vector2) + FROM_FEET
		global_position = Vector2(floorf(at.x + 0.5), floorf(at.y + 0.5))


func _draw() -> void:
	draw_rect(Rect2(0, 0, 9, 9), KEY)
	draw_rect(Rect2(0, 8, 9, 1), KEY_EDGE)
	# The E: three wide from x 3, five tall from y 2, each ink pixel on a 3x3
	# of outline first.
	for pass_ink in [false, true]:
		for k in E.length():
			if E[k] != "1":
				continue
			var at := Vector2(3 + k % 3, 2 + floori(k / 3.0))
			if pass_ink:
				draw_rect(Rect2(at, Vector2.ONE), INK)
			else:
				draw_rect(Rect2(at - Vector2.ONE, Vector2(3, 3)), OUTLINE)
