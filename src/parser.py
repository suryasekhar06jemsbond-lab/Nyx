from __future__ import annotations

API_VERSION = "1.0.0"

from enum import IntEnum
from dataclasses import dataclass
from src.lexer import Lexer
from src.token_types import ASSIGNMENT_TOKENS, DEFAULT_REGISTRY, TokenRegistry, TokenType, Token
from src.ast_nodes import (
    Program, LetStatement, Identifier, Expression, ReturnStatement,
    ExpressionStatement, IntegerLiteral, PrefixExpression, InfixExpression,
    BooleanLiteral, IfExpression, BlockStatement, FunctionLiteral, HashLiteral,
    CallExpression, ArrayLiteral, IndexExpression, NullLiteral, StringLiteral,
    FloatLiteral, ForStatement, AssignExpression, WhileStatement,
    BinaryLiteral, OctalLiteral, HexLiteral, ClassStatement, SuperExpression,
    SelfExpression, NewExpression, ImportStatement, UseStatement, FromStatement, TryStatement,
    RaiseStatement, AssertStatement, WithStatement, YieldExpression,
    AsyncStatement, AwaitExpression, PassStatement, BreakStatement, ContinueStatement, ForInStatement
)

class Precedence(IntEnum):
    LOWEST = 1
    ASSIGN = 2
    YIELD = 3
    LOGICAL = 4
    EQUALS = 5
    LESSGREATER = 6
    SUM = 7
    PRODUCT = 8
    PREFIX = 9
    CALL = 10
    INDEX = 11

PRECEDENCES = {
    TokenType.ASSIGN: Precedence.ASSIGN,
    TokenType.PLUS_ASSIGN: Precedence.ASSIGN,
    TokenType.MINUS_ASSIGN: Precedence.ASSIGN,
    TokenType.ASTERISK_ASSIGN: Precedence.ASSIGN,
    TokenType.SLASH_ASSIGN: Precedence.ASSIGN,
    TokenType.MODULO_ASSIGN: Precedence.ASSIGN,
    TokenType.FLOOR_DIVIDE_ASSIGN: Precedence.ASSIGN,
    TokenType.COLON_ASSIGN: Precedence.ASSIGN,
    TokenType.LOGICAL_AND: Precedence.LOGICAL,
    TokenType.LOGICAL_OR: Precedence.LOGICAL,
    TokenType.EQ: Precedence.EQUALS,
    TokenType.NOT_EQ: Precedence.EQUALS,
    TokenType.LT: Precedence.LESSGREATER,
    TokenType.GT: Precedence.LESSGREATER,
    TokenType.LE: Precedence.LESSGREATER,
    TokenType.GE: Precedence.LESSGREATER,
    TokenType.PLUS: Precedence.SUM,
    TokenType.MINUS: Precedence.SUM,
    TokenType.SLASH: Precedence.PRODUCT,
    TokenType.ASTERISK: Precedence.PRODUCT,
    TokenType.POWER: Precedence.PRODUCT,
    TokenType.MODULO: Precedence.PRODUCT,
    TokenType.FLOOR_DIVIDE: Precedence.PRODUCT,
    TokenType.LPAREN: Precedence.CALL,
    TokenType.LBRACKET: Precedence.INDEX,
    TokenType.DOT: Precedence.CALL,
    TokenType.YIELD: Precedence.YIELD,
}

class Parser:
    @dataclass
    class Options:
        max_errors: int = 200
        stop_on_first_error: bool = False

    def __init__(self, lexer: Lexer, options: "Parser.Options" | None = None):
        self.l = lexer
        self.cur_token: Token = None
        self.peek_token: Token = None
        self.errors = []
        self.registry: TokenRegistry = getattr(lexer, "registry", DEFAULT_REGISTRY)
        self.statement_hooks = {}
        self.error_hooks = []
        self.options = options or Parser.Options()

        self.prefix_parse_fns = {
            TokenType.IDENT: self.parse_identifier,
            TokenType.INT: self.parse_integer_literal,
            TokenType.FLOAT: self.parse_float_literal,
            TokenType.BINARY: self.parse_binary_literal,
            TokenType.OCTAL: self.parse_octal_literal,
            TokenType.HEX: self.parse_hex_literal,
            TokenType.STRING: self.parse_string_literal,
            TokenType.BANG: self.parse_prefix_expression,
            TokenType.MINUS: self.parse_prefix_expression,
            TokenType.BITWISE_NOT: self.parse_prefix_expression,
            TokenType.TRUE: self.parse_boolean,
            TokenType.FALSE: self.parse_boolean,
            TokenType.LPAREN: self.parse_grouped_expression,
            TokenType.IF: self.parse_if_expression,
            TokenType.FUNCTION: self.parse_function_literal,
            TokenType.LBRACKET: self.parse_array_literal,
            TokenType.LBRACE: self.parse_hash_literal,
            TokenType.NULL: self.parse_null_literal,
            TokenType.SUPER: self.parse_super_expression,
            TokenType.SELF: self.parse_self_expression,
            TokenType.NEW: self.parse_new_expression,
            TokenType.AWAIT: self.parse_await_expression,
            TokenType.YIELD: self.parse_yield_expression,
            TokenType.PRINT: self.parse_print_identifier,
        }

        self.infix_parse_fns = {
            TokenType.PLUS: self.parse_infix_expression,
            TokenType.MINUS: self.parse_infix_expression,
            TokenType.SLASH: self.parse_infix_expression,
            TokenType.ASTERISK: self.parse_infix_expression,
            TokenType.POWER: self.parse_infix_expression,
            TokenType.MODULO: self.parse_infix_expression,
            TokenType.FLOOR_DIVIDE: self.parse_infix_expression,
            TokenType.EQ: self.parse_infix_expression,
            TokenType.NOT_EQ: self.parse_infix_expression,
            TokenType.LT: self.parse_infix_expression,
            TokenType.GT: self.parse_infix_expression,
            TokenType.LE: self.parse_infix_expression,
            TokenType.GE: self.parse_infix_expression,
            TokenType.LOGICAL_AND: self.parse_infix_expression,
            TokenType.LOGICAL_OR: self.parse_infix_expression,
            TokenType.LPAREN: self.parse_call_expression,
            TokenType.LBRACKET: self.parse_index_expression,
            TokenType.DOT: self.parse_infix_expression,
        }
        for assign_tok in self.registry.assignment_tokens or ASSIGNMENT_TOKENS:
            self.infix_parse_fns[assign_tok] = self.parse_assign_expression

        self.next_token()
        self.next_token()

    def next_token(self):
        self.cur_token = self.peek_token
        self.peek_token = self.l.next_token()

    def parse_program(self) -> Program:
        program = Program(statements=[])
        while not self.cur_token_is(TokenType.EOF):
            stmt = self.parse_statement()
            if stmt:
                program.statements.append(stmt)
            self.next_token()
        return program

    def parse(self) -> Program:
        # Compatibility helper for older callers/tests.
        return self.parse_program()

    def register_prefix(self, token_type: TokenType, fn):
        self.prefix_parse_fns[token_type] = fn

    def register_infix(self, token_type: TokenType, fn):
        self.infix_parse_fns[token_type] = fn

    def register_statement(self, token_type: TokenType, fn):
        self.statement_hooks[token_type] = fn

    def register_error_hook(self, fn):
        self.error_hooks.append(fn)

    def _record_error(self, message: str):
        if len(self.errors) >= self.options.max_errors:
            return
        self.errors.append(message)
        for hook in self.error_hooks:
            hook(message, self)

    def parse_statement(self):
        token_type = self.cur_token.type
        custom = self.statement_hooks.get(token_type)
        if custom:
            return custom()
        if token_type == TokenType.SEMICOLON:
            return None
        if token_type == TokenType.LET:
            return self.parse_let_statement()
        elif token_type == TokenType.RETURN:
            return self.parse_return_statement()
        elif token_type == TokenType.CLASS:
            return self.parse_class_statement()
        elif token_type == TokenType.IMPORT:
            return self.parse_import_statement()
        elif token_type == TokenType.USE:
            return self.parse_use_statement()
        elif token_type == TokenType.FROM:
            return self.parse_from_statement()
        elif token_type == TokenType.TRY:
            return self.parse_try_statement()
        elif token_type == TokenType.RAISE:
            return self.parse_raise_statement()
        elif token_type == TokenType.ASSERT:
            return self.parse_assert_statement()
        elif token_type == TokenType.WITH:
            return self.parse_with_statement()
        elif token_type == TokenType.ASYNC:
            return self.parse_async_statement()
        elif token_type == TokenType.PASS:
            return self.parse_pass_statement()
        elif token_type == TokenType.BREAK:
            return self.parse_break_statement()
        elif token_type == TokenType.CONTINUE:
            return self.parse_continue_statement()
        elif token_type == TokenType.WHILE:
            return self.parse_while_statement()
        elif token_type == TokenType.FOR:
            return self.parse_for_statement()
        elif token_type == TokenType.ILLEGAL:
            self._record_error(f"Illegal token at line={self.cur_token.line} col={self.cur_token.column}: {self.cur_token.literal!r}")
            self._synchronize_statement()
            return None
        else:
            return self.parse_expression_statement()

    def parse_let_statement(self):
        token = self.cur_token
        if not self.expect_peek(TokenType.IDENT):
            return None
        name = Identifier(token=self.cur_token, value=self.cur_token.literal)
        if not self.expect_peek(TokenType.ASSIGN):
            return None
        self.next_token()
        value = self.parse_expression(Precedence.LOWEST)
        if self.peek_token_is(TokenType.SEMICOLON):
            self.next_token()
        return LetStatement(token=token, name=name, value=value)

    def parse_return_statement(self):
        token = self.cur_token
        self.next_token()
        return_value = None
        if not self.cur_token_is(TokenType.SEMICOLON):
            return_value = self.parse_expression(Precedence.LOWEST)
        if self.peek_token_is(TokenType.SEMICOLON):
            self.next_token()
        return ReturnStatement(token=token, return_value=return_value)

    def parse_expression_statement(self):
        stmt = ExpressionStatement(token=self.cur_token, expression=self.parse_expression(Precedence.LOWEST))
        if self.peek_token_is(TokenType.SEMICOLON):
            self.next_token()
        return stmt

    def parse_expression(self, precedence: Precedence):
        prefix = self.prefix_parse_fns.get(self.cur_token.type)
        if not prefix:
            self._record_error(f"No prefix parsing function for {self.cur_token.type}")
            self._synchronize_expression()
            return NullLiteral(token=self.cur_token)
        
        left_exp = prefix()

        while not self.peek_token_is(TokenType.SEMICOLON) and precedence < self.peek_precedence():
            infix = self.infix_parse_fns.get(self.peek_token.type)
            if not infix:
                return left_exp
            self.next_token()
            left_exp = infix(left_exp)
        
        return left_exp

    def parse_identifier(self):
        return Identifier(token=self.cur_token, value=self.cur_token.literal)

    def parse_print_identifier(self):
        # Keep `print(...)` usable in expression contexts.
        return Identifier(token=self.cur_token, value="print")

    def parse_integer_literal(self):
        try:
            value = int(self.cur_token.literal)
        except ValueError:
            self._record_error(f"Invalid integer literal: {self.cur_token.literal!r}")
            value = 0
        return IntegerLiteral(token=self.cur_token, value=value)
    
    def parse_float_literal(self):
        try:
            value = float(self.cur_token.literal)
        except ValueError:
            self._record_error(f"Invalid float literal: {self.cur_token.literal!r}")
            value = 0.0
        return FloatLiteral(token=self.cur_token, value=value)

    def parse_binary_literal(self):
        return BinaryLiteral(token=self.cur_token, value=self.cur_token.literal)

    def parse_octal_literal(self):
        return OctalLiteral(token=self.cur_token, value=self.cur_token.literal)

    def parse_hex_literal(self):
        return HexLiteral(token=self.cur_token, value=self.cur_token.literal)

    def parse_string_literal(self):
        return StringLiteral(token=self.cur_token, value=self.cur_token.literal)

    def parse_boolean(self):
        return BooleanLiteral(token=self.cur_token, value=self.cur_token_is(TokenType.TRUE))

    def parse_null_literal(self):
        return NullLiteral(token=self.cur_token)

    def parse_prefix_expression(self):
        token = self.cur_token
        operator = self.cur_token.literal
        self.next_token()
        right = self.parse_expression(Precedence.PREFIX)
        return PrefixExpression(token=token, operator=operator, right=right)

    def parse_infix_expression(self, left):
        token = self.cur_token
        operator = self.cur_token.literal
        precedence = self.cur_precedence()
        self.next_token()
        right = self.parse_expression(precedence)
        return InfixExpression(token=token, left=left, operator=operator, right=right)

    def parse_assign_expression(self, name):
        # Accept Identifier or InfixExpression (member access) as assignment target
        if not isinstance(name, (Identifier, InfixExpression)):
            self._record_error(f"Expected identifier on left side of assignment, got {type(name)}")
            return None
            
        token = self.cur_token
        precedence = self.cur_precedence()
        self.next_token()
        value = self.parse_expression(precedence)
        return AssignExpression(token=token, name=name, value=value)

    def parse_grouped_expression(self):
        self.next_token()
        exp = self.parse_expression(Precedence.LOWEST)
        if not self.expect_peek(TokenType.RPAREN):
            return None
        return exp

    def parse_if_expression(self):
        token = self.cur_token
        if not self.expect_peek(TokenType.LPAREN): return None
        self.next_token()
        condition = self.parse_expression(Precedence.LOWEST)
        if not self.expect_peek(TokenType.RPAREN): return None
        if not self.expect_peek(TokenType.LBRACE): return None
        consequence = self.parse_block_statement()
        
        alternative = None
        if self.peek_token_is(TokenType.ELSE):
            self.next_token()
            if not self.expect_peek(TokenType.LBRACE): return None
            alternative = self.parse_block_statement()
            
        return IfExpression(token=token, condition=condition, consequence=consequence, alternative=alternative)
    
    def parse_while_statement(self):
        token = self.cur_token
        if not self.expect_peek(TokenType.LPAREN): return None
        self.next_token()
        condition = self.parse_expression(Precedence.LOWEST)
        if not self.expect_peek(TokenType.RPAREN): return None
        if not self.expect_peek(TokenType.LBRACE): return None
        body = self.parse_block_statement()
        return WhileStatement(token=token, condition=condition, body=body)

    def parse_for_statement(self):
        token = self.cur_token
        if not self.expect_peek(TokenType.LPAREN): return None
        self.next_token()

        # for-in loop variants:
        # for (x in xs) { ... }
        # for (k, v in xs) { ... }  -> keeps `v` as iterator for compatibility
        if self.cur_token_is(TokenType.IDENT) and self.peek_token_is(TokenType.IN):
            iterator = self.parse_identifier()
            self.next_token()  # in
            self.next_token()  # iterable start
            iterable = self.parse_expression(Precedence.LOWEST)
            if not self.expect_peek(TokenType.RPAREN): return None
            if not self.expect_peek(TokenType.LBRACE): return None
            body = self.parse_block_statement()
            return ForInStatement(token=token, iterator=iterator, iterable=iterable, body=body)

        if self.cur_token_is(TokenType.IDENT) and self.peek_token_is(TokenType.COMMA):
            first_iter = self.parse_identifier()
            self.next_token()  # comma
            if not self.expect_peek(TokenType.IDENT): return None
            second_iter = self.parse_identifier()
            if not self.expect_peek(TokenType.IN): return None
            self.next_token()
            iterable = self.parse_expression(Precedence.LOWEST)
            if not self.expect_peek(TokenType.RPAREN): return None
            if not self.expect_peek(TokenType.LBRACE): return None
            body = self.parse_block_statement()
            # Preserve compatibility with existing AST shape.
            return ForInStatement(token=token, iterator=second_iter, iterable=iterable, body=body)
            
        initialization = self.parse_statement()
        self.next_token()
        condition = self.parse_expression(Precedence.LOWEST)

        if not self.expect_peek(TokenType.SEMICOLON): return None
        self.next_token()
        increment = self.parse_expression(Precedence.LOWEST)

        if not self.expect_peek(TokenType.RPAREN): return None
        if not self.expect_peek(TokenType.LBRACE): return None
        body = self.parse_block_statement()
        
        return ForStatement(token=token, initialization=initialization, condition=condition, increment=increment, body=body)


    def parse_block_statement(self):
        token = self.cur_token
        statements = []
        self.next_token()
        while not self.cur_token_is(TokenType.RBRACE) and not self.cur_token_is(TokenType.EOF):
            stmt = self.parse_statement()
            if stmt: statements.append(stmt)
            self.next_token()
        return BlockStatement(token=token, statements=statements)

    def parse_function_parameters(self) -> list[Identifier] | None:
        identifiers = []
        if self.peek_token_is(TokenType.RPAREN):
            self.next_token()
            return identifiers
        self.next_token()
        ident = Identifier(token=self.cur_token, value=self.cur_token.literal)
        identifiers.append(ident)
        while self.peek_token_is(TokenType.COMMA):
            self.next_token()
            self.next_token()
            ident = Identifier(token=self.cur_token, value=self.cur_token.literal)
            identifiers.append(ident)
        if not self.expect_peek(TokenType.RPAREN):
            return None
        return identifiers

    def parse_function_literal(self):
        token = self.cur_token
        name = None
        if self.peek_token_is(TokenType.IDENT):
            self.next_token()
            name = self.parse_identifier()

        if not self.expect_peek(TokenType.LPAREN): return None
        parameters = self.parse_function_parameters()
        if parameters is None: return None
        if not self.expect_peek(TokenType.LBRACE): return None
        body = self.parse_block_statement()
        return FunctionLiteral(token=token, parameters=parameters, body=body, name=name)

    def _parse_expression_list(self, end: TokenType) -> list[Expression] | None:
        expr_list = []
        if self.peek_token_is(end):
            self.next_token()
            return expr_list
        
        self.next_token()
        expr_list.append(self.parse_expression(Precedence.LOWEST))
        while self.peek_token_is(TokenType.COMMA):
            self.next_token()
            self.next_token()
            expr_list.append(self.parse_expression(Precedence.LOWEST))
        
        if not self.expect_peek(end):
            return None
        return expr_list

    def parse_call_expression(self, function):
        token = self.cur_token
        arguments = self._parse_expression_list(TokenType.RPAREN)
        return CallExpression(token=token, function=function, arguments=arguments)

    def parse_array_literal(self):
        token = self.cur_token
        elements = self._parse_expression_list(TokenType.RBRACKET)
        return ArrayLiteral(token=token, elements=elements)

    def parse_hash_literal(self) -> Expression | None:
        token = self.cur_token
        pairs = []
        while not self.peek_token_is(TokenType.RBRACE):
            self.next_token()
            key = self.parse_expression(Precedence.LOWEST)
            if not self.expect_peek(TokenType.COLON): return None
            self.next_token()
            value = self.parse_expression(Precedence.LOWEST)
            pairs.append((key, value))
            if not self.peek_token_is(TokenType.RBRACE) and not self.expect_peek(TokenType.COMMA): return None
        if not self.expect_peek(TokenType.RBRACE): return None
        return HashLiteral(token=token, pairs=pairs)

    def parse_index_expression(self, left):
        token = self.cur_token
        self.next_token()
        index = self.parse_expression(Precedence.LOWEST)
        if not self.expect_peek(TokenType.RBRACKET): return None
        return IndexExpression(token=token, left=left, index=index)
        
    def parse_class_statement(self):
        token = self.cur_token
        if not self.expect_peek(TokenType.IDENT): return None
        name = self.parse_identifier()
        superclass = None
        if self.peek_token_is(TokenType.COLON):
            self.next_token()
            self.next_token()
            superclass = self.parse_identifier()
        if not self.expect_peek(TokenType.LBRACE): return None
        body = self.parse_block_statement()
        return ClassStatement(token=token, name=name, superclass=superclass, body=body)

    def parse_super_expression(self):
        return SuperExpression(token=self.cur_token)

    def parse_self_expression(self):
        return SelfExpression(token=self.cur_token)

    def parse_new_expression(self):
        token = self.cur_token
        self.next_token()
        cls = self.parse_expression(Precedence.CALL)
        return NewExpression(token=token, cls=cls)

    def parse_import_statement(self):
        token = self.cur_token
        self.next_token()
        if not self.cur_token_is(TokenType.STRING):
            self._record_error("import expects a string literal path")
            return None
        path = self.parse_string_literal()
        return ImportStatement(token=token, path=path)

    def parse_use_statement(self):
        token = self.cur_token
        self.next_token()
        if not self.cur_token_is(TokenType.IDENT):
            self._record_error("use expects a module name")
            return None
        module_name = self.cur_token.literal
        self.next_token()  # advance past module name
        return UseStatement(token=token, module=module_name)

    def parse_from_statement(self):
        token = self.cur_token
        self.next_token()
        if not self.cur_token_is(TokenType.STRING):
            self._record_error("from expects a string literal path")
            return None
        path = self.parse_string_literal()
        if not self.expect_peek(TokenType.IMPORT): return None
        self.next_token()
        imports = []
        star_type = getattr(TokenType, "ASTERISK", None)
        if star_type is not None and self.cur_token_is(star_type):
            imports.append(Identifier(token=self.cur_token, value='*'))
        else:
            while self.cur_token_is(TokenType.IDENT):
                imports.append(self.parse_identifier())
                if not self.peek_token_is(TokenType.COMMA): break
                self.next_token()

        return FromStatement(token=token, path=path, imports=imports)

    def parse_try_statement(self):
        token = self.cur_token
        if not self.expect_peek(TokenType.LBRACE): return None
        try_block = self.parse_block_statement()
        except_block = None
        if self.peek_token_is(TokenType.EXCEPT):
            self.next_token()
            if not self.expect_peek(TokenType.LBRACE): return None
            except_block = self.parse_block_statement()
        finally_block = None
        if self.peek_token_is(TokenType.FINALLY):
            self.next_token()
            if not self.expect_peek(TokenType.LBRACE): return None
            finally_block = self.parse_block_statement()
        return TryStatement(token=token, try_block=try_block, except_block=except_block, finally_block=finally_block)

    def parse_raise_statement(self):
        token = self.cur_token
        self.next_token()
        exception = self.parse_expression(Precedence.LOWEST)
        return RaiseStatement(token=token, exception=exception)
        
    def parse_assert_statement(self):
        token = self.cur_token
        self.next_token()
        condition = self.parse_expression(Precedence.LOWEST)
        message = None
        if self.peek_token_is(TokenType.COMMA):
            self.next_token()
            self.next_token()
            message = self.parse_expression(Precedence.LOWEST)
        return AssertStatement(token=token, condition=condition, message=message)

    def parse_with_statement(self):
        token = self.cur_token
        self.next_token()
        context = self.parse_expression(Precedence.LOWEST)
        if not self.expect_peek(TokenType.LBRACE): return None
        body = self.parse_block_statement()
        return WithStatement(token=token, context=context, body=body)

    def parse_yield_expression(self):
        token = self.cur_token
        self.next_token()
        value = None
        if not self.cur_token_is(TokenType.SEMICOLON):
            value = self.parse_expression(Precedence.YIELD)
        return YieldExpression(token=token, value=value)

    def parse_async_statement(self):
        token = self.cur_token
        self.next_token()
        statement = self.parse_statement()
        return AsyncStatement(token=token, statement=statement)

    def parse_await_expression(self):
        token = self.cur_token
        self.next_token()
        expression = self.parse_expression(Precedence.CALL)
        return AwaitExpression(token=token, expression=expression)
        
    def parse_pass_statement(self):
        return PassStatement(token=self.cur_token)

    def parse_break_statement(self):
        return BreakStatement(token=self.cur_token)
        
    def parse_continue_statement(self):
        return ContinueStatement(token=self.cur_token)

    def cur_token_is(self, t: TokenType) -> bool:
        return self.cur_token.type == t

    def peek_precedence(self):
        return PRECEDENCES.get(self.peek_token.type, Precedence.LOWEST)

    def cur_precedence(self):
        return PRECEDENCES.get(self.cur_token.type, Precedence.LOWEST)

    def peek_token_is(self, t: TokenType) -> bool:
        return self.peek_token.type == t

    def expect_peek(self, t: TokenType) -> bool:
        if self.peek_token_is(t):
            self.next_token()
            return True
        self.peek_error(t)
        if self.options.stop_on_first_error:
            raise SyntaxError(self.errors[-1])
        return False
    
    def peek_error(self, t: TokenType):
        self._record_error(f"Expected next token to be {t}, got {self.peek_token.type} instead")

    def _synchronize_statement(self):
        sync_tokens = {
            TokenType.SEMICOLON,
            TokenType.RBRACE,
            TokenType.EOF,
        }
        while self.cur_token.type not in sync_tokens:
            self.next_token()

    def _synchronize_expression(self):
        sync_tokens = {
            TokenType.SEMICOLON,
            TokenType.COMMA,
            TokenType.RPAREN,
            TokenType.RBRACKET,
            TokenType.EOF,
        }
        while self.cur_token.type not in sync_tokens:
            self.next_token()

