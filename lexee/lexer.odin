package lexee

import "core:fmt"
import "core:slice"
import "core:unicode"
import "core:strconv"

// compiler doesnt like this since its circular :(
// LexProc :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum)) -> (cont: bool = true)

Lexer :: struct($PunctEnum, $KeywordEnum: typeid) {
	span: Span,
	input: []u8,
	tokens: [dynamic]Token(PunctEnum, KeywordEnum),

	config: Config,
	punct_map: map[string]PunctEnum,
	keyword_map: map[string]KeywordEnum,

	single_line_comment_prefix: []string,

	lex_procs: [dynamic]proc(lexer: ^Lexer(PunctEnum, KeywordEnum)) -> (cont: bool = true, err: Maybe(Error)),
}

lex :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum)) -> (tokens: []Token(PunctEnum, KeywordEnum), err: Maybe(Error)) {
	main: for !is_end(lexer) {
		lexer.span.lo = lexer.span.hi
		char := peek(lexer)

		if lex_whitespace(lexer) do continue
		if lex_punct(lexer) do continue
		if lex_keyword(lexer) do continue
		if lex_ident(lexer) do continue

		int_cont, int_err := lex_integer(lexer)
		if int_err, ok := int_err.?; ok {
			err = int_err
			return
		} else if int_cont {
			continue
		}

		str_cont, str_err := lex_string(lexer)
		if str_err, ok := str_err.?; ok {
			err = str_err
			return
		} else if str_cont {
			continue
		}

		if lex_single_line_comment(lexer) do continue

		for lex_proc in lexer.lex_procs {
			proc_cont, proc_err := lex_proc(lexer)
			if proc_err, ok := proc_err.?; ok {
				err = proc_err
				return
			} else if proc_cont {
				continue main
			}
		}

		err = Error{.InvalidCharacter, lexer.span, char}
		return
	}

	add_token(lexer, .EOF, nil)

	tokens = lexer.tokens[:]
	return
}

lex_whitespace :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum)) -> (cont: bool = true) {
	char := peek(lexer)

	// remove partial
	#partial switch lexer.config.whitespace {
	case .Ignore:
		switch char {
		case ' ', '\t', '\n', '\r':
			eat(lexer)
			return
		}
	case .Seperate:
		switch char {
		case ' ':
			eat(lexer)
			add_token(lexer, .Space, nil)
			return
		case '\t':
			eat(lexer)
			add_token(lexer, .Tab, nil)
			return
		case '\n':
			eat(lexer)
			add_token(lexer, .Newline, nil)
			return
		case '\r':
			eat(lexer)
			return
		}
	case: unimplemented()
	}

	return false
}

lex_punct :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum)) -> (cont: bool = true) {
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
			return
		}
	}

	return false
}

lex_keyword :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum)) -> (cont: bool = true) {
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
			return
		}
	}

	return false
}

lex_ident :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum)) -> (cont: bool = true) {
	char := peek(lexer)

	if is_ident_char(lexer, char) {
		eat(lexer)

		for !is_end(lexer) && is_ident_char(lexer, peek(lexer)) {
			eat(lexer)
		}

		ident_str := string(span_input_slice(lexer))
		add_token(lexer, .Ident, ident_str)

		return
	}

	return false
}

lex_integer :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum)) -> (cont: bool = true, err: Maybe(Error)) {
	char := peek(lexer)

	if unicode.is_digit(rune(char)) {
		eat(lexer)
	
		for !is_end(lexer) && unicode.is_digit(rune(peek(lexer))) {
			eat(lexer)
		}
	
		int_str := string(span_input_slice(lexer))
		int_parsed, ok := strconv.parse_uint(int_str)
	
		if !ok {
			err = Error{.InvalidInteger, lexer.span, int_str}
			return
		}
	
		add_token(lexer, .Integer, int_parsed)
	
		return
	}

	return false, nil
}

lex_string :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum)) -> (cont: bool = true, err: Maybe(Error)) {
	char := peek(lexer)

	if char == '"' {
		eat(lexer)

		str_buf: [dynamic]u8
		terminated := false
		for !is_end(lexer) && (peek(lexer) != '\n' && peek(lexer) != '\r') {
			if peek(lexer) == '"' {
				eat(lexer)
				terminated = true
				break
			}

			if peek(lexer) == '\\' {
				eat(lexer)
				switch eat(lexer) {
				case '\\':
					append(&str_buf, '\\')
					continue
				case '"':
					append(&str_buf, '\"')
					continue
				case 't':
					append(&str_buf, '\t')
					continue
				case:
					// todo: add info to error
					err = Error{.InvalidEscape, lexer.span, nil}
					return
				}
			}

			append(&str_buf, eat(lexer))
		}

		if !terminated {
			err = Error{.UnterminatedString, lexer.span, nil}
			return
		}

		str_str := string(str_buf[:])
		add_token(lexer, .String, str_str)

		return
	}

	return false, nil
}

lex_single_line_comment :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum)) -> (cont: bool = true) {
	char := peek(lexer)

	slice.sort_by(lexer.single_line_comment_prefix, proc(i, j: string) -> bool {
		return len(i) > len(j)
	})

	for s_comm_prefix in lexer.single_line_comment_prefix {
		if lexer.span.hi + len(s_comm_prefix) - 1 >= len(lexer.input) {
			continue
		}

		if s_comm_prefix == string(lexer.input)[lexer.span.hi:][:len(s_comm_prefix)] {
			lexer.span.hi += len(s_comm_prefix)

			for !is_end(lexer) && peek(lexer) != '\n' {
				eat(lexer)
			}

			if !is_end(lexer) {
				after_char := eat(lexer)
				assert(after_char == '\n', "expected newline at end of single-line comment") // eat newline
			}

			if !lexer.config.ignore_comments {
				// fixme: cuts last char of an eof comment, fix hi_off
				comment_lexeme := string(span_input_slice(lexer, len(s_comm_prefix), -1))
				add_token(lexer, .Comment, comment_lexeme)
			}

			return
		}
	}

	return false
}

is_ident_char :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum), char: u8) -> bool {
	return unicode.is_alpha(rune(char)) || slice.contains(lexer.config.ident_allowed_chars, char)
}

span_input_slice :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum), lo_off: int = 0, hi_off: int = 0, loc := #caller_location) -> []u8 {
	span := Span{uint(int(lexer.span.lo)+lo_off), uint(int(lexer.span.hi)+hi_off)}
	if is_end(lexer, span) {
		fmt.panicf(
			"Internal lexer error: Tried to span input slice when lexer ended (span=%v, slice=[%v:%v], len=%v)\nAt %v",
			span,
			lo_off, hi_off,
			len(lexer.input),
			loc,
		)
	}

	return lexer.input[int(lexer.span.lo)+lo_off:int(lexer.span.hi)+hi_off]
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

is_end :: proc(lexer: ^Lexer($PunctEnum, $KeywordEnum), span: Maybe(Span) = nil) -> bool {
	if span, ok := span.?; ok {
		return span.hi >= len(lexer.input)
	} else {
		return lexer.span.hi >= len(lexer.input)
	}
}
