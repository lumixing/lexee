package lexee

Span :: struct {
	lo, hi: uint,
}

Token :: struct($PunctEnum, $KeywordEnum: typeid) {
	span: Span,
	type: TokenType,
	value: TokenValue(PunctEnum, KeywordEnum),
}

TokenType :: enum {
	Ident,
	Punct,
	Keyword,
	
	Whitespace,
	Space,
	Tab,
	Newline,

	String,
	Integer,

	Comment,

	EOF,
}

Distinct :: struct($T: typeid) {
	type: T,
}

TokenValue :: union($PunctEnum, $KeywordEnum: typeid) {
	string,
	int,
	uint,

	Distinct(PunctEnum),
	Distinct(KeywordEnum),
}
