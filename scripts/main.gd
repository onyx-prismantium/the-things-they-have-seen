extends Node2D

## Boots the game: loads the case (already done by CaseLoader autoload),
## shows the briefing, then the room. Milestone M0 only needs this to exist
## so the project has a valid main scene; fleshed out through M1-M4.

const NOBODYWHO_PINNED_VERSION := "9.4.0" # BUILD_BRIEF.md §0.3, §2.2

func _ready() -> void:
	_log_nobodywho_status()
	if CaseLoader.current_case == null:
		push_error("Main: no case loaded")
		return
	print("Main: case '%s' ready" % CaseLoader.current_case.title)

func _log_nobodywho_status() -> void:
	if ClassDB.class_exists("NobodyWhoChat") and ClassDB.class_exists("NobodyWhoModel"):
		print("NobodyWho: plugin loaded (pinned addon release v%s)" % NOBODYWHO_PINNED_VERSION)
	else:
		print("NobodyWho: plugin NOT loaded — run tools/install_nobodywho.sh (--mock-nlu still works without it)")
