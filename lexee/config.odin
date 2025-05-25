package lexee

WhitespaceConfig :: enum {
	Ignore,
	Seperate,
	OnlyWhitespace,
	OnlyNewline,
	OnlyNewlineWhitespace,
}

Config :: struct {
	whitespace: WhitespaceConfig,

	ident_allowed_chars: []u8,
	ident_allow_digits: bool,
	// ident_allow_digits_beginning: bool,

	ignore_comments: bool,
}

config_default :: proc() -> Config {
	// cant use slice literal (gets freed before using)
	@(static) ident_allowed_chars := []u8{'_'}

	return {
		whitespace = .OnlyNewline,

		ident_allowed_chars = ident_allowed_chars,
		ident_allow_digits = true,

		ignore_comments = true,
	}
}
