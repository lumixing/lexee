package lexee

import "core:fmt"

Error :: struct {
	type: ErrorType,
	span: Span,
	info: ErrorInfo,
}

ErrorType :: enum {
	InvalidCharacter,
	InvalidInteger,
	UnterminatedString,
	InvalidEscape,
}

ErrorInfo :: union {
	string,
	u8,
}

print_error :: proc(input: []u8, err: Error) {
	line, col := span_to_line_col(input, err.span)
	fmt.printfln("Error at %d:%d: %v (%v)", line, col, err.type, err.info)
}

span_to_line_col :: proc(input: []u8, span: Span) -> (line, col: uint) {
	line = 1
	col = 1

	for char, idx in input {
		if uint(idx) == span.hi {
			break
		}

		if char == '\n' {
			line += 1
			col = 1
		} else {
			col += 1
		}
	}

	return
}
