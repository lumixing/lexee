#+feature dynamic-literals

package test

import lx "../lexee"

import "core:fmt"

INPUT: string: "ma_in() int { a = == 0; return a }"

punct_map := map[string]Punct{
	"(" = .LParen,
	")" = .RParen,
	"{" = .LBrace,
	"}" = .RBrace,
	"=" = .Eq,
	"==" = .EqEq,
	";" = .Semi,
}

Punct :: enum {
	LParen,
	RParen,
	LBrace,
	RBrace,
	Eq,
	EqEq,
	Semi,
	Int
}

keyword_map := map[string]Keyword {
	"int" = .Int,
	"return" = .Return
}

Keyword :: enum {
	Int,
	Return,
}

main :: proc() {
	lexer: lx.Lexer(Punct, Keyword)
	lexer.input = transmute([]u8)INPUT
	lexer.config = lx.config_default()
	lexer.punct_map = punct_map
	lexer.keyword_map = keyword_map
	tokens, err := lx.lex(&lexer)
	fmt.println(err)
	for token in tokens {
		fmt.println(token.type, token.value)
	}
}
