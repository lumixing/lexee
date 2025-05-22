package lexee

import "core:fmt"
import "core:reflect"
import "core:slice"
import "core:unicode"

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

Error :: struct {
	type: ErrorType,
	span: Span,
	info: ErrorInfo,
}

ErrorType :: enum {
	InvalidCharacter,
}

ErrorInfo :: union {
	string,
	u8,
}

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

	EOF,
}

Distinct :: struct($T: typeid) {
	type: T,
}

TokenValue :: union($PunctEnum, $KeywordEnum: typeid) {
	string,
	int,
	Distinct(PunctEnum),
	Distinct(KeywordEnum),
}

Lexer :: struct($PunctEnum, $KeywordEnum: typeid) {
	span: Span,
	input: []u8,
	tokens: [dynamic]Token(PunctEnum, KeywordEnum),

	config: Config,
	punct_map: map[string]PunctEnum,
	keyword_map: map[string]KeywordEnum,
}

lex :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum)) -> (tokens: []Token(PunctEnum, KeywordEnum), error: Maybe(Error)) {
	main: for !is_end(lexer) {
		lexer.span.lo = lexer.span.hi
		char := peek(lexer)

		if lexer.config.ignore_whitespace {
			switch char {
			case ' ', '\t', '\n', '\r':
				eat(lexer)
				continue
			}
		} else {
			switch char {
			case ' ':  add_token(lexer, .Space, nil)
			case '\t': add_token(lexer, .Tab, nil)
			case '\n': add_token(lexer, .Newline, nil)
			case '\r':
				eat(lexer)
				continue
			}
		}

		punct_map_entries, _ := slice.map_entries(lexer.punct_map)
		slice.sort_by(punct_map_entries, proc(i, j: slice.Map_Entry(string, PunctEnum)) -> bool {
			return len(i.key) > len(j.key)
		})

		for punct_map_entry in punct_map_entries {
			punct_str := punct_map_entry.key
			punct_enum := punct_map_entry.value

			if lexer.span.hi + len(punct_str) - 1 >= len(lexer.input) {
				continue
			}

			if punct_str == string(lexer.input)[lexer.span.hi:][:len(punct_str)] {
				lexer.span.hi += len(punct_str)
				add_token(lexer, .Punct, Distinct(PunctEnum){punct_enum})
				continue main
			}
		}

		keyword_map_entries, _ := slice.map_entries(lexer.keyword_map)
		slice.sort_by(keyword_map_entries, proc(i, j: slice.Map_Entry(string, KeywordEnum)) -> bool {
			return len(i.key) > len(j.key)
		})

		for keyword_map_entry in keyword_map_entries {
			keyword_str := keyword_map_entry.key
			keyword_enum := keyword_map_entry.value

			if lexer.span.hi + len(keyword_str) - 1 >= len(lexer.input) {
				continue
			}

			if keyword_str == string(lexer.input)[lexer.span.hi:][:len(keyword_str)] {
				lexer.span.hi += len(keyword_str)
				add_token(lexer, .Keyword, Distinct(KeywordEnum){keyword_enum})
				continue main
			}
		}

		if is_ident_char(lexer, char) {
			eat(lexer)

			for !is_end(lexer) && is_ident_char(lexer, peek(lexer)) {
				eat(lexer)
			}
			ident_str := string(span_input_slice(lexer))
			add_token(lexer, .Ident, ident_str)

			continue main
		}

		error = Error{.InvalidCharacter, lexer.span, char}
		return

		// eat(lexer)
	}

	add_token(lexer, .EOF, nil)

	tokens = lexer.tokens[:]
	return
}

is_ident_char :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum), char: u8) -> bool {
	return unicode.is_alpha(rune(char)) || slice.contains(lexer.config.ident_allowed_chars, char)
}

span_input_slice :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum), loc := #caller_location) -> []u8 {
	if is_end(lexer) {
		fmt.panicf(
			"Internal lexer error: Tried to span input slice when lexer ended (span=%v, len=%v)\nAt %v",
			lexer.span,
			len(lexer.input),
			loc,
		)
	}

	return lexer.input[lexer.span.lo:lexer.span.hi]
}

add_token :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum), type: TokenType, value: TokenValue(PunctEnum, KeywordEnum)) {
	append(&lexer.tokens, Token(PunctEnum, KeywordEnum){lexer.span, type, value})
}

eat :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum), loc := #caller_location) -> u8 {
	if is_end(lexer) {
		fmt.panicf(
			"Internal lexer error: Tried to eat when lexer ended (span=%v, len=%v)\nAte at %v",
			lexer.span,
			len(lexer.input),
			loc,
		)
	}

	defer lexer.span.hi += 1
	return lexer.input[lexer.span.hi]
}

peek :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum), loc := #caller_location) -> u8 {
	if is_end(lexer) {
		fmt.panicf(
			"Internal lexer error: Tried to peek when lexer ended (span=%v, len=%v)\nPeeked at %v",
			lexer.span,
			len(lexer.input),
			loc,
		)
	}

	return lexer.input[lexer.span.hi]
}

is_end :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum)) -> bool {
	return lexer.span.hi >= len(lexer.input)
}
