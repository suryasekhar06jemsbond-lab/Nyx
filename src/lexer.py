from __future__ import annotations

API_VERSION = "2.0.0"

from dataclasses import dataclass
from typing import Callable, Generator, List, Optional, Tuple

from src.token_types import DEFAULT_REGISTRY, Token, TokenRegistry, TokenType


class Lexer:
    """Nyx lexer with Unicode, string, and numeric literal support."""

    @dataclass
    class Options:
        allow_hash_comments: bool = True
        allow_cpp_line_comments: bool = False
        allow_c_block_comments: bool = True
        max_token_length: int = 1_000_000

        allow_multiline_strings: bool = True
        allow_format_strings: bool = True
        allow_raw_strings: bool = True
        allow_byte_strings: bool = True

        allow_unicode_identifiers: bool = True
        normalize_unicode: bool = False

        recover_from_errors: bool = True
        max_consecutive_errors: int = 1000

        enable_position_tracking: bool = True
        track_trivia: bool = False

    @dataclass
    class LexerState:
        position: int
        read_position: int
        line: int
        column: int
        byte_offset: int

    def __init__(
        self,
        source: str,
        registry: Optional[TokenRegistry] = None,
        options: Optional["Lexer.Options"] = None,
        source_file: Optional[str] = None,
    ) -> None:
        self.source = source or ""
        self.length = len(self.source)
        self.position = 0
        self.read_position = 0
        self.ch = "\0"
        self.line = 1
        self.column = 0
        self.byte_offset = 0
        self.prev_token_type: Optional[TokenType] = None
        self.registry = registry or DEFAULT_REGISTRY
        self._token_hooks: List[Callable[[Token], Token]] = []
        self.options = options or Lexer.Options()
        self.source_file = source_file
        self.current_leading_trivia = ""
        self.errors: List[Tuple[int, int, str]] = []
        self.consecutive_errors = 0
        self._read_char()

    def save_state(self) -> "Lexer.LexerState":
        return Lexer.LexerState(
            position=self.position,
            read_position=self.read_position,
            line=self.line,
            column=self.column,
            byte_offset=self.byte_offset,
        )

    def restore_state(self, state: "Lexer.LexerState") -> None:
        self.position = state.position
        self.read_position = state.read_position
        self.line = state.line
        self.column = state.column
        self.byte_offset = state.byte_offset
        if self.position < self.length:
            self.ch = self.source[self.position]
        else:
            self.ch = "\0"

    def record_error(self, message: str) -> None:
        self.errors.append((self.line, self.column, message))
        self.consecutive_errors += 1
        if self.consecutive_errors >= self.options.max_consecutive_errors:
            raise RuntimeError(
                f"Too many consecutive lexer errors (line {self.line}, col {self.column})"
            )

    def clear_trivia(self) -> None:
        self.current_leading_trivia = ""

    def add_token_hook(self, hook: Callable[[Token], Token]) -> None:
        self._token_hooks.append(hook)

    def register_token_hook(self, hook: Callable[[Token], Token]) -> None:
        self.add_token_hook(hook)

    def _apply_hooks(self, token: Token) -> Token:
        if self.source_file:
            token.source_file = self.source_file
        if self.options.track_trivia and self.current_leading_trivia:
            token.leading_trivia = self.current_leading_trivia
            self.current_leading_trivia = ""
        if token.type != TokenType.ILLEGAL:
            self.consecutive_errors = 0
        token = self.registry.transform_token(token)
        for hook in self._token_hooks:
            token = hook(token)
        return token

    def _read_char(self) -> None:
        if self.read_position >= self.length:
            self.position = self.read_position
            self.ch = "\0"
            return
        self.ch = self.source[self.read_position]
        self.position = self.read_position
        self.read_position += 1
        if self.ch == "\n":
            self.line += 1
            self.column = 0
        else:
            self.column += 1
        if self.options.enable_position_tracking:
            self.byte_offset += len(self.ch.encode("utf-8"))

    def _peek_char(self) -> str:
        if self.read_position >= self.length:
            return "\0"
        return self.source[self.read_position]

    def _peek_n(self, n: int) -> str:
        end = self.position + n
        if end > self.length:
            return ""
        return self.source[self.position:end]

    def _skip_whitespace_and_comments(self) -> None:
        trivia_start = self.position
        while True:
            while self.ch in (" ", "\t", "\r", "\n"):
                self._read_char()

            if self.options.allow_hash_comments and self.ch == "#":
                while self.ch not in ("\n", "\0"):
                    self._read_char()
                continue

            if self.options.allow_cpp_line_comments and self.ch == "/" and self._peek_char() == "/":
                self._read_char()
                self._read_char()
                while self.ch not in ("\n", "\0"):
                    self._read_char()
                continue

            if self.options.allow_c_block_comments and self.ch == "/" and self._peek_char() == "*":
                self._read_char()
                self._read_char()
                self._skip_block_comment()
                continue

            break
        if self.options.track_trivia and trivia_start < self.position:
            self.current_leading_trivia = self.source[trivia_start:self.position]
        elif not self.options.track_trivia:
            self.current_leading_trivia = ""

    def _skip_block_comment(self) -> None:
        depth = 1
        while depth > 0 and self.ch != "\0":
            if self.ch == "/" and self._peek_char() == "*":
                depth += 1
                self._read_char()
                self._read_char()
                continue
            if self.ch == "*" and self._peek_char() == "/":
                depth -= 1
                self._read_char()
                self._read_char()
                continue
            self._read_char()

    def _is_identifier_char(self, ch: str) -> bool:
        if ch.isalnum() or ch == "_":
            return True
        if not self.options.allow_unicode_identifiers:
            return False
        if ord(ch) <= 127:
            return False
        try:
            return ch.isidentifier()
        except Exception:
            return False

    def _read_identifier(self) -> str:
        start = self.position
        while self._is_identifier_char(self.ch):
            self._read_char()
        text = self.source[start:self.position]
        if len(text) > self.options.max_token_length:
            text = text[: self.options.max_token_length]
        if self.options.normalize_unicode and self.options.allow_unicode_identifiers:
            import unicodedata

            text = unicodedata.normalize("NFC", text)
        return text

    def _read_number(self, signed: bool = False) -> Tuple[TokenType, str]:
        start = self.position
        if signed and self.ch == "-":
            self._read_char()

        if self.ch == "0" and self._peek_char() in ("b", "B"):
            self._read_char()
            self._read_char()
            lit_start = self.position
            while self.ch in ("0", "1"):
                self._read_char()
            return TokenType.BINARY, self.source[lit_start:self.position]

        if self.ch == "0" and self._peek_char() in ("o", "O"):
            self._read_char()
            self._read_char()
            lit_start = self.position
            while self.ch in "01234567":
                self._read_char()
            return TokenType.OCTAL, self.source[lit_start:self.position]

        if self.ch == "0" and self._peek_char() in ("x", "X"):
            self._read_char()
            self._read_char()
            lit_start = self.position
            while self.ch.isdigit() or self.ch.lower() in "abcdef":
                self._read_char()
            return TokenType.HEX, self.source[lit_start:self.position]

        saw_dot = False
        saw_exp = False
        while True:
            if self.ch.isdigit():
                self._read_char()
                continue
            if self.ch == "." and not saw_dot and not saw_exp:
                saw_dot = True
                self._read_char()
                continue
            if self.ch in ("e", "E") and not saw_exp:
                saw_exp = True
                self._read_char()
                if self.ch in ("+", "-"):
                    self._read_char()
                continue
            break

        lit = self.source[start:self.position]
        if len(lit) > self.options.max_token_length:
            lit = lit[: self.options.max_token_length]
        if lit.startswith("-.") or lit.startswith("."):
            return TokenType.FLOAT, lit
        if saw_dot or saw_exp:
            return TokenType.FLOAT, lit
        return TokenType.INT, lit

    def _read_string(self, quote: str) -> str:
        self._read_char()
        chars: List[str] = []
        while self.ch not in ("\0", quote):
            if self.ch == "\\":
                self._read_char()
                escape_map = {
                    "n": "\n",
                    "t": "\t",
                    "r": "\r",
                    "\\": "\\",
                    '"': '"',
                    "'": "'",
                }
                chars.append(escape_map.get(self.ch, self.ch))
            else:
                chars.append(self.ch)
            self._read_char()
        literal = "".join(chars)
        if self.ch == quote:
            self._read_char()
        if len(literal) > self.options.max_token_length:
            literal = literal[: self.options.max_token_length]
        return literal

    def _read_raw_string(self, quote: str) -> str:
        self._read_char()
        if self.ch != quote:
            self.record_error(f"Expected {quote} after r prefix")
            return ""
        self._read_char()
        chars: List[str] = []
        while self.ch not in ("\0", quote):
            chars.append(self.ch)
            self._read_char()
        if self.ch == quote:
            self._read_char()
        literal = "".join(chars)
        if len(literal) > self.options.max_token_length:
            literal = literal[: self.options.max_token_length]
        return literal

    def _read_multiline_string(self, quote: str) -> str:
        self._read_char()
        self._read_char()
        self._read_char()
        chars: List[str] = []
        while self.ch != "\0":
            if self.ch == quote and self._peek_char() == quote and self._peek_n(2)[1:2] == quote:
                self._read_char()
                self._read_char()
                self._read_char()
                break
            chars.append(self.ch)
            self._read_char()
        literal = "".join(chars)
        if len(literal) > self.options.max_token_length:
            literal = literal[: self.options.max_token_length]
        return literal

    def _read_format_string(self, quote: str) -> Tuple[str, List[Tuple[int, str]]]:
        self._read_char()
        if self.ch != quote:
            self.record_error(f"Expected {quote} after f prefix")
            return "", []
        self._read_char()

        parts: List[str] = []
        interpolations: List[Tuple[int, str]] = []
        current: List[str] = []

        while self.ch not in ("\0", quote):
            if self.ch == "{":
                self._read_char()
                if self.ch == "{":
                    current.append("{")
                    self._read_char()
                    continue
                expr_chars: List[str] = []
                brace_depth = 1
                while self.ch != "\0" and brace_depth > 0:
                    if self.ch == "{":
                        brace_depth += 1
                    elif self.ch == "}":
                        brace_depth -= 1
                        if brace_depth == 0:
                            break
                    expr_chars.append(self.ch)
                    self._read_char()
                if self.ch == "}":
                    self._read_char()
                expr = "".join(expr_chars).strip()
                parts.append("".join(current))
                interpolations.append((len(parts) - 1, expr))
                current = []
                continue
            if self.ch == "\\":
                self._read_char()
                escape_map = {
                    "n": "\n",
                    "t": "\t",
                    "r": "\r",
                    "\\": "\\",
                    '"': '"',
                    "'": "'",
                }
                current.append(escape_map.get(self.ch, self.ch))
                self._read_char()
                continue
            current.append(self.ch)
            self._read_char()

        if self.ch == quote:
            self._read_char()
        parts.append("".join(current))

        result = "".join(
            f"{p}{{}}" if idx < len(interpolations) and interpolations[idx][0] == idx else p
            for idx, p in enumerate(parts)
        )
        return result, interpolations

    def _can_start_signed_number(self) -> bool:
        if self.ch != "-" or not (self._peek_char().isdigit() or self._peek_char() == "."):
            return False
        if self.prev_token_type is None:
            return True
        return self.prev_token_type in {
            TokenType.ASSIGN,
            TokenType.PLUS,
            TokenType.MINUS,
            TokenType.ASTERISK,
            TokenType.SLASH,
            TokenType.MODULO,
            TokenType.FLOOR_DIVIDE,
            TokenType.LPAREN,
            TokenType.LBRACKET,
            TokenType.COMMA,
            TokenType.COLON,
            TokenType.SEMICOLON,
            TokenType.RETURN,
            TokenType.LET,
        }

    def _make_token(
        self,
        token_type: TokenType,
        literal: str,
        line: int,
        col: int,
        byte_offset: int,
        byte_length: int,
    ) -> Token:
        tok = Token(token_type, literal, line, col)
        tok.byte_offset = byte_offset
        tok.byte_length = byte_length
        self.prev_token_type = token_type
        return tok

    def next_token(self) -> Token:
        self._skip_whitespace_and_comments()
        line, col = self.line, self.column

        if self.ch == "\0":
            return self._apply_hooks(self._make_token(TokenType.EOF, "", line, col, self.byte_offset, 0))

        byte_start = self.byte_offset - len(self.ch.encode("utf-8"))

        for op, token_type in self.registry.multi_char_tokens:
            if self._peek_n(len(op)) == op:
                for _ in op:
                    self._read_char()
                byte_len = self.byte_offset - byte_start
                return self._apply_hooks(
                    self._make_token(token_type, op, line, col, byte_start, byte_len)
                )

        if self._can_start_signed_number():
            token_type, lit = self._read_number(signed=True)
            byte_len = self.byte_offset - byte_start
            return self._apply_hooks(
                self._make_token(token_type, lit, line, col, byte_start, byte_len)
            )

        if self.ch.isdigit() or (self.ch == "." and self._peek_char().isdigit()):
            token_type, lit = self._read_number(signed=False)
            byte_len = self.byte_offset - byte_start
            return self._apply_hooks(
                self._make_token(token_type, lit, line, col, byte_start, byte_len)
            )

        if self.ch in ("\"", "'"):
            quote = self.ch
            if (
                self.options.allow_multiline_strings
                and self._peek_n(3) == quote * 3
            ):
                lit = self._read_multiline_string(quote)
                byte_len = self.byte_offset - byte_start
                tok = self._make_token(TokenType.STRING, lit, line, col, byte_start, byte_len)
                tok.metadata["multiline"] = True
                return self._apply_hooks(tok)
            lit = self._read_string(quote)
            byte_len = self.byte_offset - byte_start
            return self._apply_hooks(
                self._make_token(TokenType.STRING, lit, line, col, byte_start, byte_len)
            )

        if self.ch in ("r", "R") and self._peek_char() in ("\"", "'") and self.options.allow_raw_strings:
            quote = self._peek_char()
            lit = self._read_raw_string(quote)
            byte_len = self.byte_offset - byte_start
            tok = self._make_token(TokenType.STRING, lit, line, col, byte_start, byte_len)
            tok.metadata["raw"] = True
            return self._apply_hooks(tok)

        if self.ch in ("b", "B") and self._peek_char() in ("\"", "'") and self.options.allow_byte_strings:
            quote = self._peek_char()
            lit = self._read_raw_string(quote)
            byte_len = self.byte_offset - byte_start
            tok = self._make_token(TokenType.STRING, lit, line, col, byte_start, byte_len)
            tok.metadata["bytes"] = True
            return self._apply_hooks(tok)

        if self.ch in ("f", "F") and self._peek_char() in ("\"", "'") and self.options.allow_format_strings:
            quote = self._peek_char()
            lit, interpolations = self._read_format_string(quote)
            byte_len = self.byte_offset - byte_start
            tok = self._make_token(TokenType.STRING, lit, line, col, byte_start, byte_len)
            tok.metadata["format"] = True
            tok.metadata["interpolations"] = interpolations
            return self._apply_hooks(tok)

        if self._is_identifier_char(self.ch):
            ident = self._read_identifier()
            token_type = self.registry.lookup_ident(ident)
            byte_len = self.byte_offset - byte_start
            return self._apply_hooks(
                self._make_token(token_type, ident, line, col, byte_start, byte_len)
            )

        tok_type = self.registry.single_char_tokens.get(self.ch, TokenType.ILLEGAL)
        lit = self.ch
        self._read_char()
        byte_len = self.byte_offset - byte_start

        if tok_type == TokenType.ILLEGAL and self.options.recover_from_errors:
            self.record_error(f"Unexpected character: {lit!r}")
            return self.next_token()

        return self._apply_hooks(
            self._make_token(tok_type, lit, line, col, byte_start, byte_len)
        )

    def tokens(self) -> Generator[Token, None, None]:
        while True:
            tok = self.next_token()
            yield tok
            if tok.type == TokenType.EOF:
                break

    def tokenize(self) -> Generator[Token, None, None]:
        return self.tokens()
