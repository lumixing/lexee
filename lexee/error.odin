package lexee

Error :: struct {
	type: ErrorType,
	span: Span,
	info: ErrorInfo,
}

ErrorType :: enum {
	InvalidCharacter,
	InvalidInteger,
	UnterminatedString,
}

ErrorInfo :: union {
	string,
	u8,
}
