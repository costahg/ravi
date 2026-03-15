extends Node

const TRACKS: Dictionary = {
	"main": preload("res://assets/audio/end_of_beginning.ogg"),
	"finale": preload("res://assets/audio/goo_goo_dolls.ogg"),
}
const BGM_FADE_DURATION: float = 0.5
const BGM_MUTED_VOLUME_DB: float = -80.0
const BGM_DEFAULT_VOLUME_DB: float = 0.0

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var _bgm_tween: Tween
var _bgm_transition_in_progress: bool = false
var _current_bgm_track_key: String = ""
var _requested_bgm_track_key: String = ""
var _stop_bgm_requested: bool = false
var _stop_bgm_fade_duration: float = BGM_FADE_DURATION


func _ready() -> void:
	_ensure_players()
	_configure_bgm_tracks()


func _ensure_players() -> void:
	if bgm_player == null:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.name = "bgm_player"
		bgm_player.volume_db = BGM_DEFAULT_VOLUME_DB
		add_child(bgm_player)

	if sfx_player == null:
		sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "sfx_player"
		add_child(sfx_player)


func play_bgm(track_key: String) -> void:
	_ensure_players()
	_configure_bgm_tracks()

	if not TRACKS.has(track_key):
		push_warning("AudioManager.play_bgm ignorado: track_key inexistente: %s" % track_key)
		return

	var track: AudioStream = TRACKS.get(track_key)
	if track == null:
		push_warning("AudioManager.play_bgm ignorado: track nula para key %s" % track_key)
		return

	if _requested_bgm_track_key == track_key:
		return

	if _current_bgm_track_key == track_key and bgm_player.playing and not _stop_bgm_requested:
		return

	_requested_bgm_track_key = track_key
	_stop_bgm_requested = false
	_process_bgm_requests()


func play_sfx(sfx: AudioStream) -> void:
	_ensure_players()
	sfx_player.stream = sfx
	sfx_player.play()


func stop_bgm(fade_duration: float = 0.5) -> void:
	_ensure_players()

	if not bgm_player.playing and _current_bgm_track_key == "" and _requested_bgm_track_key == "":
		return

	_requested_bgm_track_key = ""
	_stop_bgm_requested = true
	_stop_bgm_fade_duration = max(fade_duration, 0.0)
	_process_bgm_requests()


func _process_bgm_requests() -> void:
	if _bgm_transition_in_progress:
		return

	_bgm_transition_in_progress = true

	while true:
		if _stop_bgm_requested:
			var fade_duration: float = _stop_bgm_fade_duration
			_stop_bgm_requested = false

			if bgm_player.playing:
				await _fade_bgm_volume_to(BGM_MUTED_VOLUME_DB, fade_duration)
				bgm_player.stop()

			bgm_player.stream = null
			bgm_player.volume_db = BGM_DEFAULT_VOLUME_DB
			_current_bgm_track_key = ""

			if _requested_bgm_track_key != "":
				continue

			break

		var next_track_key: String = _requested_bgm_track_key
		_requested_bgm_track_key = ""

		if next_track_key == "":
			break

		var next_track: AudioStream = TRACKS.get(next_track_key)
		if next_track == null:
			push_warning("AudioManager.play_bgm ignorado: track nula para key %s" % next_track_key)
			continue

		if _current_bgm_track_key == next_track_key and bgm_player.playing:
			bgm_player.volume_db = BGM_DEFAULT_VOLUME_DB
			continue

		if bgm_player.playing:
			await _fade_bgm_volume_to(BGM_MUTED_VOLUME_DB, BGM_FADE_DURATION)
			bgm_player.stop()

		bgm_player.stream = next_track
		bgm_player.volume_db = BGM_MUTED_VOLUME_DB
		bgm_player.play()
		_current_bgm_track_key = next_track_key

		await _fade_bgm_volume_to(BGM_DEFAULT_VOLUME_DB, BGM_FADE_DURATION)

		if _stop_bgm_requested:
			continue

		if _requested_bgm_track_key != "" and _requested_bgm_track_key != _current_bgm_track_key:
			continue

		break

	_bgm_transition_in_progress = false


func _fade_bgm_volume_to(target_volume_db: float, duration: float) -> void:
	if duration <= 0.0:
		bgm_player.volume_db = target_volume_db
		return

	_bgm_tween = create_tween()
	_bgm_tween.tween_property(bgm_player, "volume_db", target_volume_db, duration)
	await _bgm_tween.finished
	_bgm_tween = null


func _configure_bgm_tracks() -> void:
	for track_variant in TRACKS.values():
		var track: AudioStream = track_variant
		var ogg_track: AudioStreamOggVorbis = track as AudioStreamOggVorbis
		if ogg_track == null:
			continue

		ogg_track.loop = true
