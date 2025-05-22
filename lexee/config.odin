package lexee

Config :: struct {
	ignore_whitespace: bool,

	ident_allowed_chars: []u8,
	ident_allow_digits: bool,
	// ident_allow_digits_beginning: bool,
}

config_default :: proc() -> Config {
	// cant use slice literal (gets freed before using)
	@(static) ident_allowed_chars := []u8{'_'}

	return {
		ignore_whitespace = true,

		ident_allowed_chars = ident_allowed_chars,
		ident_allow_digits = true,
	}
}
