from enum import Enum, auto

API_VERSION = "2.0.0"  # Bumped for new features
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional, Tuple, Set

class TokenType(Enum):
    ILLEGAL = auto()
    EOF = auto()

    # Identifiers + literals
    IDENT = auto()
    INT = auto()
    FLOAT = auto()
    STRING = auto()
    BINARY = auto()
    OCTAL = auto()
    HEX = auto()

    # Operators
    ASSIGN = auto()
    PLUS = auto()
    MINUS = auto()
    BANG = auto()
    ASTERISK = auto()
    SLASH = auto()
    POWER = auto()
    MODULO = auto()
    FLOOR_DIVIDE = auto()
    BITWISE_AND = auto()
    BITWISE_OR = auto()
    BITWISE_XOR = auto()
    BITWISE_NOT = auto()
    LEFT_SHIFT = auto()
    RIGHT_SHIFT = auto()

    PLUS_ASSIGN = auto()
    MINUS_ASSIGN = auto()
    ASTERISK_ASSIGN = auto()
    SLASH_ASSIGN = auto()
    MODULO_ASSIGN = auto()
    FLOOR_DIVIDE_ASSIGN = auto()
    LOGICAL_AND = auto()
    LOGICAL_OR = auto()
    COLON_ASSIGN = auto()
    ARROW = auto()


    LT = auto()
    GT = auto()
    LE = auto()
    GE = auto()
    EQ = auto()
    NOT_EQ = auto()

    # Delimiters
    COMMA = auto()
    SEMICOLON = auto()
    COLON = auto()
    DOT = auto()
    AT = auto()

    LPAREN = auto()
    RPAREN = auto()
    LBRACE = auto()
    RBRACE = auto()
    LBRACKET = auto()
    RBRACKET = auto()

    # Special operators for future use
    QUESTION_DOT = auto()  # Optional chaining: obj?.prop
    NULL_COALESCE = auto()  # Null coalescing: a ?? b
    RANGE = auto()  # Range: 0..10
    RANGE_INCLUSIVE = auto()  # Inclusive range: 0..=10
    SPREAD = auto()  # Spread operator: ...items
    PIPELINE = auto()  # Pipeline: value |> func
    SPACESHIP = auto()  # Three-way comparison: a <=> b
    SAFE_CAST = auto()  # Safe cast: as?
    ELVIS = auto()  # Elvis: ?:
    DOUBLE_COLON = auto()  # Namespace: Module::func
    THIN_ARROW = auto()  # Lambda: ->
    FAT_ARROW = auto()  # => already exists as ARROW
    HASH = auto()  # Macro/directive: #
    DOUBLE_HASH = auto()  # Token paste: ##
    QUESTION = auto()  # Ternary/optional: ?
    AMPERSAND_ASSIGN = auto()  # Bitwise AND assign: &=
    PIPE_ASSIGN = auto()  # Bitwise OR assign: |=
    XOR_ASSIGN = auto()  # Bitwise XOR assign: ^=
    LEFT_SHIFT_ASSIGN = auto()  # Left shift assign: <<=
    RIGHT_SHIFT_ASSIGN = auto()  # Right shift assign: >>=
    POWER_ASSIGN = auto()  # Power assign: **=
    OR_ASSIGN = auto()  # Logical OR assign: ||=
    AND_ASSIGN = auto()  # Logical AND assign: &&=
    NULL_COALESCE_ASSIGN = auto()  # Null coalesce assign: ??=

    # Keywords - Core
    FUNCTION = auto()
    LET = auto()
    MUT = auto()  # Mutable: let mut x
    CONST = auto()  # Const declaration
    VAR = auto()  # Variable declaration (legacy support)
    TRUE = auto()
    FALSE = auto()
    IF = auto()
    ELSE = auto()
    ELIF = auto()  # elif for chain conditions
    RETURN = auto()
    WHILE = auto()
    FOR = auto()
    IN = auto()
    BREAK = auto()
    CONTINUE = auto()
    PRINT = auto()
    
    # Keywords - OOP
    CLASS = auto()
    STRUCT = auto()  # Struct/value type
    TRAIT = auto()  # Trait/interface
    INTERFACE = auto()  # Interface
    IMPL = auto()  # Implementation block
    ENUM = auto()  # Enum type
    SUPER = auto()
    SELF = auto()
    NEW = auto()
    EXTENDS = auto()  # Class extension
    IMPLEMENTS = auto()  # Interface implementation
    
    # Keywords - Modules
    IMPORT = auto()
    USE = auto()
    FROM = auto()
    AS = auto()
    EXPORT = auto()  # Export declaration
    PUB = auto()  # Public visibility
    PRIV = auto()  # Private visibility
    MOD = auto()  # Module declaration
    NAMESPACE = auto()  # Namespace
    PACKAGE = auto()  # Package declaration
    
    # Keywords - Error Handling
    TRY = auto()
    CATCH = auto()  # Alternative to EXCEPT
    EXCEPT = auto()
    FINALLY = auto()
    RAISE = auto()
    THROW = auto()  # Alternative to RAISE
    ASSERT = auto()
    
    # Keywords - Async/Concurrency
    WITH = auto()
    YIELD = auto()
    ASYNC = auto()
    AWAIT = auto()
    SPAWN = auto()  # Spawn concurrent task
    CHANNEL = auto()  # Channel type
    SELECT = auto()  # Select statement for channels
    LOCK = auto()  # Lock/mutex
    ACTOR = auto()  # Actor model
    
    # Keywords - Control Flow
    MATCH = auto()  # Pattern matching
    CASE = auto()  # Match case
    WHEN = auto()  # Guard/conditional pattern
    WHERE = auto()  # Type constraints
    LOOP = auto()  # Infinite loop
    DO = auto()  # Do-while
    GOTO = auto()  # Goto (for future, not recommended but sometimes needed)
    DEFER = auto()  # Defer execution
    
    # Keywords - Types
    TYPE = auto()  # Type alias
    TYPEOF = auto()  # Get type
    INSTANCEOF = auto()  # Type check
    IS = auto()  # Type check operator
    STATIC = auto()  # Static member
    DYNAMIC = auto()  # Dynamic type
    ANY = auto()  # Any type
    VOID = auto()  # Void type
    NEVER = auto()  # Never type
    
    # Keywords - Meta/Advanced
    PASS = auto()
    NULL = auto()
    NONE = auto()  # Alternative to NULL
    UNDEFINED = auto()  # Undefined value
    MACRO = auto()  # Macro definition
    INLINE = auto()  # Inline hint
    UNSAFE = auto()  # Unsafe block
    EXTERN = auto()  # External function
    REF = auto()  # Reference
    MOVE = auto()  # Move semantics
    COPY = auto()  # Copy semantics
    SIZEOF = auto()  # Size of type
    ALIGNOF = auto()  # Alignment of type
    GLOBAL = auto()  # Global variable
    STATIC_ASSERT = auto()  # Compile-time assertion
    COMPTIME = auto()  # Compile-time execution


@dataclass
class Token:
    type: TokenType
    literal: str
    line: int
    column: int
    
    # Extended position tracking for advanced tooling
    byte_offset: int = 0  # Byte offset from start of file
    byte_length: int = 0  # Length of token in bytes
    
    # Source mapping and metadata
    source_file: Optional[str] = None  # Source file path
    leading_trivia: Optional[str] = None  # Whitespace/comments before token
    trailing_trivia: Optional[str] = None  # Whitespace/comments after token
    
    # Semantic metadata (populated during parsing/analysis)
    semantic_type: Optional[str] = None  # Variable, function, class, etc.
    scope_depth: int = 0  # Lexical scope depth
    
    # Error recovery metadata
    is_inserted: bool = False  # Token was inserted during error recovery
    is_removed: bool = False   # Token skipped during error recovery
    
    # Extension hook for custom metadata
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def with_position(self, byte_offset: int, byte_length: int) -> "Token":
        """Create a copy with position information."""
        self.byte_offset = byte_offset
        self.byte_length = byte_length
        return self
    
    def with_source(self, source_file: str) -> "Token":
        """Create a copy with source file information."""
        self.source_file = source_file
        return self
    
    def with_trivia(self, leading: Optional[str] = None, trailing: Optional[str] = None) -> "Token":
        """Add trivia (whitespace/comments) to token."""
        if leading is not None:
            self.leading_trivia = leading
        if trailing is not None:
            self.trailing_trivia = trailing
        return self
    
    def with_metadata(self, key: str, value: Any) -> "Token":
        """Add custom metadata to token."""
        self.metadata[key] = value
        return self

keywords = {
    "fn": TokenType.FUNCTION,
    "let": TokenType.LET,
    "mut": TokenType.MUT,
    "const": TokenType.CONST,
    "var": TokenType.VAR,
    "true": TokenType.TRUE,
    "false": TokenType.FALSE,
    "if": TokenType.IF,
    "else": TokenType.ELSE,
    "elif": TokenType.ELIF,
    "return": TokenType.RETURN,
    "while": TokenType.WHILE,
    "for": TokenType.FOR,
    "in": TokenType.IN,
    "break": TokenType.BREAK,
    "continue": TokenType.CONTINUE,
    "print": TokenType.PRINT,
    "class": TokenType.CLASS,
    "struct": TokenType.STRUCT,
    "trait": TokenType.TRAIT,
    "interface": TokenType.INTERFACE,
    "impl": TokenType.IMPL,
    "enum": TokenType.ENUM,
    "super": TokenType.SUPER,
    "self": TokenType.SELF,
    "new": TokenType.NEW,
    "extends": TokenType.EXTENDS,
    "implements": TokenType.IMPLEMENTS,
    "import": TokenType.IMPORT,
    "use": TokenType.USE,
    "from": TokenType.FROM,
    "as": TokenType.AS,
    "export": TokenType.EXPORT,
    "pub": TokenType.PUB,
    "priv": TokenType.PRIV,
    "mod": TokenType.MOD,
    "namespace": TokenType.NAMESPACE,
    "package": TokenType.PACKAGE,
    "try": TokenType.TRY,
    "catch": TokenType.CATCH,
    "except": TokenType.EXCEPT,
    "finally": TokenType.FINALLY,
    "raise": TokenType.RAISE,
    "throw": TokenType.THROW,
    "assert": TokenType.ASSERT,
    "with": TokenType.WITH,
    "yield": TokenType.YIELD,
    "async": TokenType.ASYNC,
    "await": TokenType.AWAIT,
    "spawn": TokenType.SPAWN,
    "channel": TokenType.CHANNEL,
    "select": TokenType.SELECT,
    "lock": TokenType.LOCK,
    "actor": TokenType.ACTOR,
    "match": TokenType.MATCH,
    "case": TokenType.CASE,
    "when": TokenType.WHEN,
    "where": TokenType.WHERE,
    "loop": TokenType.LOOP,
    "do": TokenType.DO,
    "goto": TokenType.GOTO,
    "defer": TokenType.DEFER,
    "type": TokenType.TYPE,
    "typeof": TokenType.TYPEOF,
    "instanceof": TokenType.INSTANCEOF,
    "is": TokenType.IS,
    "static": TokenType.STATIC,
    "dynamic": TokenType.DYNAMIC,
    "any": TokenType.ANY,
    "void": TokenType.VOID,
    "never": TokenType.NEVER,
    "pass": TokenType.PASS,
    "null": TokenType.NULL,
    "none": TokenType.NONE,
    "undefined": TokenType.UNDEFINED,
    "macro": TokenType.MACRO,
    "inline": TokenType.INLINE,
    "unsafe": TokenType.UNSAFE,
    "extern": TokenType.EXTERN,
    "ref": TokenType.REF,
    "move": TokenType.MOVE,
    "copy": TokenType.COPY,
    "sizeof": TokenType.SIZEOF,
    "alignof": TokenType.ALIGNOF,
    "global": TokenType.GLOBAL,
    "static_assert": TokenType.STATIC_ASSERT,
    "comptime": TokenType.COMPTIME,
}

# Stable public aliases so downstream code can depend on names that won't change.
KEYWORDS = keywords

# Operator registries are the single source of truth used by lexer/parser.
MULTI_CHAR_TOKENS: List[Tuple[str, TokenType]] = [
    # Three-character operators (longest first for proper matching)
    ("//=", TokenType.FLOOR_DIVIDE_ASSIGN),
    ("<<=", TokenType.LEFT_SHIFT_ASSIGN),
    (">>=", TokenType.RIGHT_SHIFT_ASSIGN),
    ("**=", TokenType.POWER_ASSIGN),
    ("||=", TokenType.OR_ASSIGN),
    ("&&=", TokenType.AND_ASSIGN),
    ("??=", TokenType.NULL_COALESCE_ASSIGN),
    ("..=", TokenType.RANGE_INCLUSIVE),
    ("<=>", TokenType.SPACESHIP),
    ("...", TokenType.SPREAD),
    ("::", TokenType.DOUBLE_COLON),
    ("##", TokenType.DOUBLE_HASH),
    
    # Two-character operators
    ("<<", TokenType.LEFT_SHIFT),
    (">>", TokenType.RIGHT_SHIFT),
    ("==", TokenType.EQ),
    ("!=", TokenType.NOT_EQ),
    ("<=", TokenType.LE),
    (">=", TokenType.GE),
    ("+=", TokenType.PLUS_ASSIGN),
    ("-=", TokenType.MINUS_ASSIGN),
    ("*=", TokenType.ASTERISK_ASSIGN),
    ("/=", TokenType.SLASH_ASSIGN),
    ("%=", TokenType.MODULO_ASSIGN),
    ("&=", TokenType.AMPERSAND_ASSIGN),
    ("|=", TokenType.PIPE_ASSIGN),
    ("^=", TokenType.XOR_ASSIGN),
    ("//", TokenType.FLOOR_DIVIDE),
    ("**", TokenType.POWER),
    ("&&", TokenType.LOGICAL_AND),
    ("||", TokenType.LOGICAL_OR),
    (":=", TokenType.COLON_ASSIGN),
    ("=>", TokenType.ARROW),
    ("->", TokenType.THIN_ARROW),
    ("..", TokenType.RANGE),
    ("??", TokenType.NULL_COALESCE),
    ("?.", TokenType.QUESTION_DOT),
    ("|>", TokenType.PIPELINE),
    ("?:", TokenType.ELVIS),
]

SINGLE_CHAR_TOKENS: Dict[str, TokenType] = {
    "=": TokenType.ASSIGN,
    "+": TokenType.PLUS,
    "-": TokenType.MINUS,
    "!": TokenType.BANG,
    "*": TokenType.ASTERISK,
    "/": TokenType.SLASH,
    "%": TokenType.MODULO,
    "&": TokenType.BITWISE_AND,
    "|": TokenType.BITWISE_OR,
    "^": TokenType.BITWISE_XOR,
    "~": TokenType.BITWISE_NOT,
    "<": TokenType.LT,
    ">": TokenType.GT,
    ",": TokenType.COMMA,
    ";": TokenType.SEMICOLON,
    ":": TokenType.COLON,
    ".": TokenType.DOT,
    "@": TokenType.AT,
    "#": TokenType.HASH,
    "?": TokenType.QUESTION,
    "(": TokenType.LPAREN,
    ")": TokenType.RPAREN,
    "{": TokenType.LBRACE,
    "}": TokenType.RBRACE,
    "[": TokenType.LBRACKET,
    "]": TokenType.RBRACKET,
}

ASSIGNMENT_TOKENS = {
    TokenType.ASSIGN,
    TokenType.PLUS_ASSIGN,
    TokenType.MINUS_ASSIGN,
    TokenType.ASTERISK_ASSIGN,
    TokenType.SLASH_ASSIGN,
    TokenType.MODULO_ASSIGN,
    TokenType.FLOOR_DIVIDE_ASSIGN,
    TokenType.COLON_ASSIGN,
    TokenType.AMPERSAND_ASSIGN,
    TokenType.PIPE_ASSIGN,
    TokenType.XOR_ASSIGN,
    TokenType.LEFT_SHIFT_ASSIGN,
    TokenType.RIGHT_SHIFT_ASSIGN,
    TokenType.POWER_ASSIGN,
    TokenType.OR_ASSIGN,
    TokenType.AND_ASSIGN,
    TokenType.NULL_COALESCE_ASSIGN,
}


def lookup_ident(literal: str) -> TokenType:
    return KEYWORDS.get(literal, TokenType.IDENT)


@dataclass
class TokenRegistry:
    """
    Runtime-extensible token registry with advanced features.
    
    This registry supports:
    - Dynamic keyword/operator registration
    - Token categories for semantic analysis
    - Precedence levels for operators
    - Context-sensitive tokens (e.g., 'async' can be identifier in some contexts)
    - Plugin hooks for custom token behavior
    
    Examples:
        # Add a custom keyword
        registry.register_keyword("match", TokenType.MATCH)
        
        # Add a custom operator with precedence
        registry.register_operator("|>", TokenType.PIPELINE, precedence=5)
        
        # Register a token transformer
        registry.add_transformer(lambda tok: ...) 
    """

    keywords: Dict[str, TokenType]
    multi_char_tokens: List[Tuple[str, TokenType]]
    single_char_tokens: Dict[str, TokenType]
    assignment_tokens: set
    
    # Advanced features
    contextual_keywords: Dict[str, TokenType] = field(default_factory=dict)
    operator_precedence: Dict[TokenType, int] = field(default_factory=dict)
    operator_associativity: Dict[TokenType, str] = field(default_factory=dict)  # 'left', 'right', 'none'
    token_categories: Dict[TokenType, str] = field(default_factory=dict)  # Category labels
    soft_keywords: set[str] = field(default_factory=set)  # Can be identifiers in some contexts
    transformers: List[Callable[[Token], Token]] = field(default_factory=list)
    
    # Future extensibility hooks
    on_keyword_registered: Optional[Callable[[str, TokenType], None]] = None
    on_operator_registered: Optional[Callable[[str, TokenType], None]] = None

    @classmethod
    def create_default(cls) -> "TokenRegistry":
        registry = cls(
            keywords=dict(KEYWORDS),
            multi_char_tokens=list(MULTI_CHAR_TOKENS),
            single_char_tokens=dict(SINGLE_CHAR_TOKENS),
            assignment_tokens=set(ASSIGNMENT_TOKENS),
        )
        
        # Initialize operator precedence (compatible with existing parser)
        registry.operator_precedence.update({
            TokenType.ASSIGN: 2,
            TokenType.OR_ASSIGN: 2,
            TokenType.AND_ASSIGN: 2,
            TokenType.NULL_COALESCE_ASSIGN: 2,
            TokenType.LOGICAL_OR: 4,
            TokenType.LOGICAL_AND: 4,
            TokenType.NULL_COALESCE: 4,
            TokenType.EQ: 5,
            TokenType.NOT_EQ: 5,
            TokenType.LT: 6,
            TokenType.GT: 6,
            TokenType.LE: 6,
            TokenType.GE: 6,
            TokenType.PIPELINE: 6,
            TokenType.PLUS: 7,
            TokenType.MINUS: 7,
            TokenType.ASTERISK: 8,
            TokenType.SLASH: 8,
            TokenType.MODULO: 8,
            TokenType.FLOOR_DIVIDE: 8,
            TokenType.POWER: 9,
            TokenType.DOT: 10,
            TokenType.QUESTION_DOT: 10,
            TokenType.LPAREN: 10,  # Call
            TokenType.LBRACKET: 11,  # Index
        })
        
        # Initialize associativity
        for tok in [TokenType.POWER]:
            registry.operator_associativity[tok] = 'right'
        for tok in [TokenType.PLUS, TokenType.MINUS, TokenType.ASTERISK, TokenType.SLASH]:
            registry.operator_associativity[tok] = 'left'
            
        # Soft keywords (can be identifiers in some contexts)
        registry.soft_keywords = {'async', 'await', 'match', 'trait', 'macro'}
        
        return registry

    def register_keyword(self, text: str, token_type: TokenType = TokenType.IDENT, 
                        soft: bool = False, contextual: bool = False) -> None:
        """
        Register a keyword.
        
        Args:
            text: The keyword text
            token_type: Token type to assign
            soft: Whether it's a soft keyword (can be identifier in some contexts)
            contextual: Whether it's context-sensitive
        """
        if text and isinstance(text, str):
            if contextual:
                self.contextual_keywords[text] = token_type
            else:
                self.keywords[text] = token_type
            
            if soft:
                self.soft_keywords.add(text)
                
            if self.on_keyword_registered:
                self.on_keyword_registered(text, token_type)

    def register_operator(self, text: str, token_type: TokenType, 
                         assignment_like: bool = False, 
                         precedence: Optional[int] = None,
                         associativity: str = 'left') -> None:
        """
        Register an operator.
        
        Args:
            text: Operator text
            token_type: Token type
            assignment_like: Whether it's an assignment operator
            precedence: Operator precedence level
            associativity: 'left', 'right', or 'none'
        """
        if not text:
            return
            
        if len(text) == 1:
            self.single_char_tokens[text] = token_type
        else:
            self.multi_char_tokens = [pair for pair in self.multi_char_tokens if pair[0] != text]
            self.multi_char_tokens.append((text, token_type))
            # Longest match first
            self.multi_char_tokens.sort(key=lambda it: len(it[0]), reverse=True)
            
        if assignment_like:
            self.assignment_tokens.add(token_type)
            
        if precedence is not None:
            self.operator_precedence[token_type] = precedence
            
        if associativity in ('left', 'right', 'none'):
            self.operator_associativity[token_type] = associativity
            
        if self.on_operator_registered:
            self.on_operator_registered(text, token_type)

    def add_transformer(self, func: Callable[[Token], Token]) -> None:
        """Add a token transformer function."""
        self.transformers.append(func)
        
    def transform_token(self, token: Token) -> Token:
        """Apply all registered transformers to a token."""
        result = token
        for transformer in self.transformers:
            result = transformer(result)
        return result

    def lookup_ident(self, literal: str, context: Optional[str] = None) -> TokenType:
        """
        Look up identifier, considering context.
        
        Args:
            literal: The identifier text
            context: Optional context hint (e.g., 'type_position', 'statement_start')
        
        Returns:
            Token type (keyword or IDENT)
        """
        # Check contextual keywords first if context provided
        if context and literal in self.contextual_keywords:
            return self.contextual_keywords[literal]
            
        # Check regular keywords
        return self.keywords.get(literal, TokenType.IDENT)
    
    def is_soft_keyword(self, literal: str) -> bool:
        """Check if a keyword can be used as identifier."""
        return literal in self.soft_keywords
        
    def get_precedence(self, token_type: TokenType) -> int:
        """Get operator precedence."""
        return self.operator_precedence.get(token_type, 0)
        
    def get_associativity(self, token_type: TokenType) -> str:
        """Get operator associativity."""
        return self.operator_associativity.get(token_type, 'left')
    
    def categorize(self, token_type: TokenType, category: str) -> None:
        """Assign a semantic category to a token type."""
        self.token_categories[token_type] = category
        
    def get_category(self, token_type: TokenType) -> Optional[str]:
        """Get the semantic category of a token type."""
        return self.token_categories.get(token_type)


DEFAULT_REGISTRY = TokenRegistry.create_default()


def create_registry(overrides: Optional[Dict[str, object]] = None) -> TokenRegistry:
    """
    Create a token registry with optional overrides.
    
    Args:
        overrides: Dict with optional keys:
            - keywords: Dict[str, str] mapping text to token type name
            - operators: List[Dict] with text, token, precedence, associativity
            - soft_keywords: List[str] of soft keyword names
            - transformers: List[Callable] of token transformers
    
    Returns:
        Configured TokenRegistry instance
    """
    registry = TokenRegistry.create_default()
    if not overrides:
        return registry

    # Register custom keywords
    kws = overrides.get("keywords")
    if isinstance(kws, dict):
        for text, token_name in kws.items():
            if not isinstance(text, str):
                continue
            soft = text in overrides.get("soft_keywords", [])
            if isinstance(token_name, str) and hasattr(TokenType, token_name):
                registry.register_keyword(text, getattr(TokenType, token_name), soft=soft)
            else:
                registry.register_keyword(text, soft=soft)

    # Register custom operators
    ops = overrides.get("operators")
    if isinstance(ops, list):
        for item in ops:
            if not isinstance(item, dict):
                continue
            text = item.get("text")
            tok_name = item.get("token")
            assignment_like = bool(item.get("assignment_like", False))
            precedence = item.get("precedence")
            associativity = item.get("associativity", "left")
            
            if isinstance(text, str) and isinstance(tok_name, str) and hasattr(TokenType, tok_name):
                registry.register_operator(
                    text, 
                    getattr(TokenType, tok_name), 
                    assignment_like=assignment_like,
                    precedence=precedence,
                    associativity=associativity
                )
    
    # Add transformers
    transformers = overrides.get("transformers")
    if isinstance(transformers, list):
        for func in transformers:
            if callable(func):
                registry.add_transformer(func)
    
    return registry


# ============================================================================
# Helper Functions & Constants
# ============================================================================

def is_keyword(literal: str, registry: Optional[TokenRegistry] = None) -> bool:
    """Check if a literal is a keyword."""
    reg = registry or DEFAULT_REGISTRY
    return literal in reg.keywords


def is_operator(token_type: TokenType) -> bool:
    """Check if a token type is an operator."""
    return token_type in {
        TokenType.PLUS, TokenType.MINUS, TokenType.ASTERISK, TokenType.SLASH,
        TokenType.MODULO, TokenType.POWER, TokenType.FLOOR_DIVIDE,
        TokenType.EQ, TokenType.NOT_EQ, TokenType.LT, TokenType.GT,
        TokenType.LE, TokenType.GE, TokenType.LOGICAL_AND, TokenType.LOGICAL_OR,
        TokenType.BITWISE_AND, TokenType.BITWISE_OR, TokenType.BITWISE_XOR,
        TokenType.BITWISE_NOT, TokenType.LEFT_SHIFT, TokenType.RIGHT_SHIFT,
        TokenType.PIPELINE, TokenType.DOT, TokenType.QUESTION_DOT,
        TokenType.NULL_COALESCE, TokenType.RANGE, TokenType.RANGE_INCLUSIVE,
        TokenType.SPACESHIP, TokenType.SPREAD, TokenType.DOUBLE_COLON,
    }


def is_assignment(token_type: TokenType, registry: Optional[TokenRegistry] = None) -> bool:
    """Check if a token type is an assignment operator."""
    reg = registry or DEFAULT_REGISTRY
    return token_type in reg.assignment_tokens


def is_literal(token_type: TokenType) -> bool:
    """Check if a token type represents a literal value."""
    return token_type in {
        TokenType.INT, TokenType.FLOAT, TokenType.STRING,
        TokenType.BINARY, TokenType.OCTAL, TokenType.HEX,
        TokenType.TRUE, TokenType.FALSE, TokenType.NULL,
        TokenType.NONE, TokenType.UNDEFINED,
    }


def is_type_keyword(token_type: TokenType) -> bool:
    """Check if a token is a type-related keyword."""
    return token_type in {
        TokenType.TYPE, TokenType.TYPEOF, TokenType.INSTANCEOF,
        TokenType.IS, TokenType.ANY, TokenType.VOID, TokenType.NEVER,
        TokenType.STRUCT, TokenType.TRAIT, TokenType.INTERFACE, TokenType.ENUM,
    }


# Token categories for semantic analysis
TOKEN_CATEGORIES = {
    "keyword": {TokenType.LET, TokenType.CONST, TokenType.VAR, TokenType.IF, TokenType.ELSE, TokenType.WHILE, TokenType.FOR},
    "operator": set(filter(is_operator, TokenType)),
    "literal": set(filter(is_literal, TokenType)),
    "delimiter": {TokenType.LPAREN, TokenType.RPAREN, TokenType.LBRACE, TokenType.RBRACE, TokenType.LBRACKET, TokenType.RBRACKET},
    "punctuation": {TokenType.COMMA, TokenType.SEMICOLON, TokenType.COLON, TokenType.DOT},
}
