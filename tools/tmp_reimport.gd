extends SceneTree
## Rebuilds .godot/imported/<name>.wav-<md5(path)>.sample (+ .md5) after a wav
## is replaced on disk, per AUDIO_HANDOFF §4: no editor launch. The saved
## resource is 16-bit PCM like the caches the previous audio sessions left
## (the .import compress/mode only applies when the editor itself reimports).

const NAMES := ["alarm", "footstep1", "footstep2", "footstep3", "door_lock",
	"ambience_night"]


func _initialize() -> void:
	var failures := 0
	for n in NAMES:
		if not _rebuild(n):
			failures += 1
	print("REIMPORT DONE failures=%d" % failures)
	quit(failures)


func _rebuild(n: String) -> bool:
	var src := "res://audio/%s.wav" % n
	var import_text := FileAccess.get_file_as_string(src + ".import")
	var re := RegEx.create_from_string("res://\\.godot/imported/\\S+?\\.sample")
	var m := re.search(import_text)
	if m == null:
		push_error("reimport: no dest path in %s.import" % src)
		return false
	var dest := m.get_string()

	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		push_error("reimport: cannot read %s" % src)
		return false
	if f.get_buffer(4).get_string_from_ascii() != "RIFF":
		push_error("reimport: %s is not RIFF" % src)
		return false
	f.get_32()
	if f.get_buffer(4).get_string_from_ascii() != "WAVE":
		push_error("reimport: %s is not WAVE" % src)
		return false
	var channels := 2
	var rate := 44100
	var bits := 16
	var data := PackedByteArray()
	while f.get_position() + 8 <= f.get_length():
		var cid := f.get_buffer(4).get_string_from_ascii()
		var csize: int = f.get_32()
		if cid == "fmt ":
			if f.get_16() != 1:
				push_error("reimport: %s is not PCM" % src)
				return false
			channels = f.get_16()
			rate = f.get_32()
			f.get_32()
			f.get_16()
			bits = f.get_16()
			if csize > 16:
				f.get_buffer(csize - 16)
		elif cid == "data":
			data = f.get_buffer(csize)
		else:
			f.get_buffer(csize)
		if csize % 2 == 1:
			f.get_8()
	f.close()
	if data.is_empty() or bits != 16:
		push_error("reimport: %s bad fmt (bits=%d, data=%d)" % [src, bits, data.size()])
		return false

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = channels == 2
	wav.data = data
	# ResourceSaver picks the saver by extension and knows no ".sample", so save
	# as a binary .res (same RSRC container) and rename onto the cache path.
	var tmp := dest + ".res"
	var err := ResourceSaver.save(wav, tmp)
	if err != OK:
		push_error("reimport: save failed for %s (%d)" % [dest, err])
		return false
	err = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),
		ProjectSettings.globalize_path(dest))
	if err != OK:
		push_error("reimport: rename onto %s failed (%d)" % [dest, err])
		return false

	var md5_path := dest.trim_suffix(".sample") + ".md5"
	var mf := FileAccess.open(md5_path, FileAccess.WRITE)
	mf.store_string("source_md5=\"%s\"\ndest_md5=\"%s\"\n" % [
		FileAccess.get_md5(src), FileAccess.get_md5(dest)])
	mf.close()

	# Read back through the remap: the length the game will actually see.
	var check := load(src) as AudioStreamWAV
	var expect_s := float(data.size()) / 2.0 / channels / rate
	var ok := check != null and absf(check.get_length() - expect_s) < 0.01
	print("reimport %-16s -> %.3fs (expect %.3fs) %s" % [n,
		check.get_length() if check != null else -1.0, expect_s,
		"OK" if ok else "MISMATCH"])
	return ok
