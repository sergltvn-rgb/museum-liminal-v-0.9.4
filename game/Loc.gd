class_name Loc
extends RefCounted
## Format-safe translation lookup.
##
## `tr(KEY) % args` is a trap. When KEY is missing from the catalogue, tr()
## returns the key itself — a string with no format specifiers — and `%` then
## fails with "String formatting error". Measured on Godot 4.7, what happens next
## depends on how the operands are typed:
##
## * Both operands statically typed — `tr(K) % [a, b]`, `tr(K) % some_int` — is
##   the ordinary shape, and it compiles to the validated `%`. The engine logs
##   "String formatting error" and the expression yields the format string
##   *unchanged*, then execution carries on to the next statement. The player is
##   left reading a bare KEY, or a literal "%s" where a number belonged.
## * An operand typed as Variant — a Dictionary field, an untyped parameter or
##   local — takes the unvalidated path, where a script error aborts the
##   enclosing function at that statement. One absent key then becomes a
##   half-built failure screen, a trial that spawns no monoliths, or a HUD that
##   stops updating, and the cause reads as a cosmetic text bug.
##
## So the abort is real but conditional; the guaranteed outcome is broken text on
## screen plus a console line nobody sees in a shipped build. The same holds if a
## translator edits a row and drops a `%s`.
##
## Loc.fmt() checks before it formats and degrades to readable output instead.
## Use it everywhere a translated string is fed to `%`; plain tr() is still the
## right call when there are no arguments.

## Matches Godot's %-format specifiers. "%%" is a literal percent sign; it is
## matched so that it can be accounted for, but it consumes no argument.
## Dynamic width ("%*d") is deliberately NOT matched: it consumes two arguments
## rather than one, so treating it as a specifier would make the arity check lie.
## Leaving it unmatched turns it into an unaccounted "%", which
## _is_accounted_for() below rejects outright.
const _SPECIFIER_PATTERN := "%(%|[-+ #0]*[0-9]*(\\.[0-9]+)?[sdfxXoceEgGvb])"

static var _specifier_regex: RegEx = null


## Translate `key` and apply `args` to it. Never raises, whatever the catalogue
## contains.
static func fmt(key: String, args: Array = []) -> String:
	var text := String(TranslationServer.translate(key))
	if args.is_empty():
		return text
	var matches := _specifiers(text)
	var expected := 0
	for found in matches:
		if found.get_string() != "%%":
			expected += 1
	if expected != args.size():
		# Either the key is missing (translate() echoes the key back, and a bare
		# key carries no specifiers) or the row and the call site disagree.
		return _degrade(key, text, args,
			"expects %d format argument(s), got %d" % [expected, args.size()])
	if not _is_accounted_for(text, matches):
		# A stray "%" that no specifier claims -- an unescaped percent sign in the
		# text, or a construct this parser does not model. Godot's own formatter
		# errors out on it and hands back the raw format string, or aborts the
		# caller outright where the validated operator does not apply; both are
		# what this class exists to prevent.
		return _degrade(key, text, args, "contains an unescaped or unsupported '%'")
	return text % args


## Every "%" in `text` must belong to a recognised specifier. Each "%%" accounts
## for two, every other specifier for one.
static func _is_accounted_for(text: String, matches: Array[RegExMatch]) -> bool:
	var claimed := 0
	for found in matches:
		claimed += found.get_string().count("%")
	return claimed == text.count("%")


static func _degrade(key: String, text: String, args: Array, reason: String) -> String:
	push_error("Loc.fmt: '%s' %s" % [key, reason])
	# Unformatted text still reads; the key alone does not, so append the values.
	return text if text != key else "%s %s" % [key, args]


static func _specifiers(text: String) -> Array[RegExMatch]:
	if _specifier_regex == null:
		_specifier_regex = RegEx.new()
		_specifier_regex.compile(_SPECIFIER_PATTERN)
	return _specifier_regex.search_all(text)
