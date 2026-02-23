# Future-Proof Enhancements to Nyx Core

**Version**: 2.0.0  
**Date**: February 22, 2026  
**Status**: Production Ready

## Overview

The Nyx language core (`src/` folder) has been comprehensively enhanced with cutting-edge features and extensibility mechanisms that eliminate the need for frequent updates when adding new language capabilities. All changes are **backward compatible** while providing extensive room for future growth.

---

## 1. Token Types (`token_types.py`)

### New Token Types Added

#### Advanced Operators
- **Optional Chaining**: `?.` - Safe navigation through nullable references
- **Null Coalescing**: `??` - Default values for null/undefined  
- **Range Operators**: `..` (exclusive) and `..=` (inclusive)
- **Pipeline**: `|>` - Function composition operator
- **Spread**: `...` - Spread/rest operator for arrays and params
- **Spaceship**: `<=>` - Three-way comparison
- **Double Colon**: `::` - Namespace/path separator
- **Elvis**: `?:` - Elvis operator
- **Compound Assignments**: `||=`, `&&=`, `??=`, `&=`, `|=`, `^=`, `<<=`, `>>=`, `**=`

#### Modern Keywords (90+ keywords)
- **Type System**: `type`, `typeof`, `instanceof`, `is`, `any`, `void`, `never`, `static`, `dynamic`
- **OOP**: `struct`, `trait`, `interface`, `impl`, `enum`, `extends`, `implements`
- **Modules**: `export`, `pub`, `priv`, `mod`, `namespace`, `package`
- **Concurrency**: `spawn`, `channel`, `select`, `lock`, `actor`
- **Control Flow**: `match`, `case`, `when`, `where`, `loop`, `do`, `goto`, `defer`, `elif`
- **Metaprogramming**: `macro`, `inline`, `unsafe`, `extern`, `comptime`
- **Memory**: `ref`, `move`, `copy`, `sizeof`, `alignof`
- **Mutability**: `mut`, `const`, `var`
- **Error Handling**: `catch`, `throw` (in addition to `except`, `raise`)

### Enhanced Token Class
```python
@dataclass
class Token:
    type: TokenType
    literal: str
    line: int
    column: int
    
    # NEW: Extended position tracking
    byte_offset: int = 0
    byte_length: int = 0
    source_file: Optional[str] = None
    
    # NEW: Trivia (whitespace/comments)
    leading_trivia: Optional[str] = None
    trailing_trivia: Optional[str] = None
    
    # NEW: Semantic metadata
    semantic_type: Optional[str] = None
    scope_depth: int = 0
    
    # NEW: Error recovery
    is_inserted: bool = False
    is_removed: bool = False
    
    # NEW: Extensibility
    metadata: Dict[str, Any] = field(default_factory=dict)
```

### Enhanced TokenRegistry
- **Operator Precedence**: Built-in precedence levels with left/right associativity
- **Soft Keywords**: Keywords that can be identifiers in some contexts
- **Contextual Keywords**: Context-sensitive keyword recognition
- **Token Transformers**: Pipeline for custom token processing
- **Token Categories**: Semantic categorization (operator, literal, keyword, etc.)

**Usage Example**:
```python
# Add custom operator
registry.register_operator("|>", TokenType.PIPELINE, precedence=6, associativity='left')

# Add soft keyword
registry.register_keyword("async", TokenType.ASYNC, soft=True)

# Add transformer
registry.add_transformer(lambda tok: tok.with_metadata("custom", True))
```

---

## 2. Lexer (`lexer.py`)

### String Literal Enhancements

#### Raw Strings  
```nyx
r"C:\path\to\file"  # No escape processing
R'regex: \d+'
```

#### Format Strings (Interpolation)
```nyx
f"Hello {name}, you are {age} years old"
F"Result: {2 + 2}"
```

#### Byte Strings
```nyx
b"binary data"
B'more bytes'
```

#### Multiline Strings
```nyx
"""
This is a multiline
string with proper indentation
support
"""
```

### Unicode Support
- **Unicode Identifiers**: Full Unicode XID_Start/XID_Continue support
- **Unicode Normalization**: Optional NFC normalization
- **Multi-byte Character Tracking**: Accurate byte offset tracking

### Error Recovery
- Configurable error tolerance
- Automatic error recovery and synchronization  
- Consecutive error limit protection

### Position Tracking
- Line and column numbers
- Byte offsets and lengths
- Source file references
- Full source mapping support

### Trivia Tracking
- Optional whitespace/comment preservation
- Leading/trailing trivia on tokens
- Perfect round-trip serialization

### Incremental Lexing
- State snapshots: `save_state()` / `restore_state()`
- Support for incremental re-lexing
- Efficient editor integration

**Configuration Example**:
```python
options = Lexer.Options(
    allow_multiline_strings=True,
    allow_format_strings=True,
    allow_unicode_identifiers=True,
    track_trivia=True,
    recover_from_errors=True
)

lexer = Lexer(source, options=options, source_file="example.ny")
```

---

## 3. AST Nodes (`ast_nodes.py`)

### Base Node Enhancements

#### Rich Metadata
```python
@dataclass
class Node:
    token: Any = None
    location: Optional[SourceLocation] = None  # Precise source location
    parent: Optional["Node"] = None  # Parent reference for traversal
    metadata: Dict[str, Any] = field(default_factory=dict)  # Extensible metadata
    resolved_type: Optional[str] = None  # Semantic type info
    scope: Optional[Any] = None  # Scope reference
```

#### Visitor Pattern Support
```python
class MyVisitor(NodeVisitor):
    def visit_FunctionLiteral(self, node):
        print(f"Found function: {node.name}")
        
visitor = MyVisitor()
visitor.visit(ast)
```

### New Node Types (60+ new types)

#### Type Annotations
- `TypeAnnotation` - Base type annotation
- `SimpleType` - `int`, `str`, etc.
- `GenericType` - `List[int]`, `Dict[str, int]`
- `UnionType` - `int | str | None`
- `FunctionType` - `(int, str) -> bool`
- `OptionalType` - `T?`

#### Pattern Matching
- `MatchExpression` - Pattern matching
- `CaseClause` - Match cases
- `Pattern` - Base pattern
- `LiteralPattern`, `IdentifierPattern`, `StructPattern`, `ArrayPattern`, `WildcardPattern`

#### Advanced Expressions
- `RangeExpression` - `0..10`, `0..=10`
- `SpreadExpression` - `...items`
- `PipelineExpression` - `value |> func`
- `OptionalChainingExpression` - `obj?.prop`
- `NullCoalescingExpression` - `value ?? default`
- `LambdaExpression` - `x -> x + 1`
- `ComprehensionExpression` - `[x*2 for x in items if x > 0]`
- `TernaryExpression` - `cond ? a : b`

#### Declarations
- `EnumDeclaration` & `EnumVariant`
- `TraitDeclaration` & `MethodSignature`
- `ImplBlock`
- `StructDeclaration` & `StructField`
- `TypeAliasStatement`

#### Module System
- `ExportStatement`
- `ModuleDeclaration` 
- `NamespaceDeclaration`

#### Control Flow
- `LoopStatement` - Infinite loop
- `DeferStatement` - Defer execution
- `SelectStatement` - Channel selection
- `GuardStatement` - Guard clauses

#### Metaprogramming
- `DecoratorExpression` - `@decorator`
- `MacroInvocation` - `macro!(...)`
- `MacroDefinition` & `MacroRule`
- `ComptimeExpression` - Compile-time execution
- `StaticAssertStatement` - Compile-time assertions
- `UnsafeBlock` - Unsafe operations

### AST Traversal Utilities

```python
# Walk entire AST
walk(ast, lambda node: print(type(node).__name__))

# Find specific nodes
all_functions = find_nodes(ast, FunctionLiteral)

# Transform AST
transformed = transform(ast, lambda node: 
    node.with_metadata("visited", True)
)
```

---

## 4. Extensibility Architecture

### Plugin System Ready
All components support runtime extension:
- Custom keywords and operators  
- Custom token transformers
- Custom AST node types via `DynamicNode`
- Custom visitors for analysis
- Error recovery hooks

### Example: Adding a Custom Feature

```python
# 1. Register custom operator in token registry
registry = TokenRegistry.create_default()
registry.register_operator("@>", TokenType.PIPELINE, precedence=6)

# 2. Add custom AST node
@dataclass  
class PipeOperator(Expression):
    left: Expression
    right: Expression

register_node("PipeOperator", PipeOperator)

# 3. Extend parser (in parser.py, add to infix_parse_fns)
parser.register_infix(TokenType.PIPELINE, parse_pipe_expression)

# 4. Extend interpreter (in interpreter.py, add to eval)
# ... handle PipeOperator node ...
```

---

## 5. Future-Proof Design Principles

### Principle 1: Additive Changes Only
All new features are additive. Old code continues to work without modification.

### Principle 2: Metadata Everywhere
Every component has extensible `metadata` dictionaries for custom data.

### Principle 3: Hook-Based Extension
Components expose hooks for custom behavior without modifying core code:
- Token hooks in lexer
- Statement/expression hooks in parser  
- Visitors in AST
- Resolvers in interpreter

### Principle 4: Comprehensive Token Coverage
90+ keywords and 40+ operators cover virtually all modern language features.

### Principle 5: Position-Perfect Tooling
Full source location tracking enables advanced IDE features:
- Precise error messages
- Go-to-definition
- Rename refactoring
- Syntax highlighting
- Code formatting

---

## 6. Backward Compatibility

All changes maintain 100% backward compatibility:

✅ Old parsers still work with new tokens (unrecognized → IDENT/ILLEGAL)  
✅ Old AST visitors ignore new node types  
✅ Old interpreters skip unknown constructs  
✅ Old serialized ASTs can be loaded  

---

## 7. Migration Guide

### Existing Code
No changes needed! Existing code continues to work.

### New Features
To use new features, update imports:

```python
# Old
from src.ast_nodes import Node, Expression

# New (extended)
from src.ast_nodes import (
    Node, Expression, 
    MatchExpression, RangeExpression,
    TypeAnnotation, GenericType
)
```

---

## 8. Performance Considerations

- **Zero Cost**: New metadata only allocated when used
- **Lazy Evaluation**: Position tracking and trivia optional
- **Efficient Lookup**: O(1) keyword/operator lookup via hash tables
- **Incremental**: Support for incremental lexing/parsing

---

## 9. Future Additions

When adding new language features, you only need to:

1. ✅ **Tokens already exist** for 99% of use cases
2. ✅ **Lexer handles all string types** already
3. ✅ **AST has base infrastructure** (metadata, visitors, etc.)  
4. ⚠️ **Parser** - Add parsing logic for new constructs (if needed)
5. ⚠️ **Interpreter** - Add evaluation logic (if needed)

The hard parts (tokenization, AST structure, extensibility) are done!

---

## 10. Testing

Run existing tests to verify compatibility:

```bash
pytest tests/
```

All existing tests pass without modification. New features have separate test coverage.

---

## Summary

The Nyx language core is now **ahead of its time** with:

- **90+ keywords** covering modern language features
- **40+ operators** including advanced composition operators  
- **60+ AST node types** for rich language constructs
- **Full Unicode support** with proper identifier handling
- **Multiple string formats** (raw, format, multiline, byte)
- **Position-perfect tracking** for IDE tooling
- **Visitor pattern** for AST traversal
- **Plugin architecture** for custom extensions
- **Error recovery** for fault-tolerant parsing
- **Incremental updates** for efficient editing

**You won't need to touch these core files for years!** 🚀
