from __future__ import annotations

API_VERSION = "2.0.0"  # Bumped for new features

from dataclasses import dataclass, field
from dataclasses import fields, is_dataclass
from typing import Any, Callable, Dict, List, Optional, Type, Union, Tuple


# ============================================================================
# Base Node Classes with Rich Metadata
# ============================================================================

@dataclass
class SourceLocation:
    """Precise source location for AST nodes."""
    line: int = 0
    column: int = 0
    byte_offset: int = 0
    byte_length: int = 0
    source_file: Optional[str] = None


@dataclass
class Node:
    """
    Base AST node with extended metadata for advanced tooling.
    
    Features:
    - Source location tracking
    - Semantic metadata
    - Parent node references (for traversal)
    - Custom metadata extensibility
    - Visitor pattern support
    """
    token: Any = None
    
    # Extended metadata
    location: Optional[SourceLocation] = None
    parent: Optional["Node"] = None  # Parent node for traversal
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    # Semantic info (populated during analysis)
    resolved_type: Optional[str] = None  # Resolved type for expressions
    scope: Optional[Any] = None  # Scope reference
    
    def accept(self, visitor: "NodeVisitor") -> Any:
        """Visitor pattern support."""
        method_name = f"visit_{self.__class__.__name__}"
        method = getattr(visitor, method_name, visitor.generic_visit)
        return method(self)
    
    def with_location(self, line: int, column: int, byte_offset: int = 0, byte_length: int = 0) -> "Node":
        """Add source location to node."""
        self.location = SourceLocation(line, column, byte_offset, byte_length)
        return self
    
    def with_metadata(self, key: str, value: Any) -> "Node":
        """Add custom metadata."""
        self.metadata[key] = value
        return self


class NodeVisitor:
    """
    Base visitor for traversing AST.
    Override visit_* methods for specific node types.
    """
    
    def visit(self, node: Node) -> Any:
        """Visit a node."""
        return node.accept(self)
    
    def generic_visit(self, node: Node) -> Any:
        """Default visit implementation."""
        return None


class Statement(Node):
    pass


class Expression(Node):
    pass


@dataclass
class Program(Node):
    statements: List[Statement] = field(default_factory=list)

    def __str__(self) -> str:
        return "".join(str(s) for s in self.statements)


@dataclass
class Identifier(Expression):
    value: str = ""

    def __str__(self) -> str:
        return self.value


@dataclass
class LetStatement(Statement):
    name: Identifier = field(default_factory=Identifier)
    value: Optional[Expression] = None

    def __str__(self) -> str:
        return f"let {self.name} = {self.value};"


@dataclass
class ReturnStatement(Statement):
    return_value: Optional[Expression] = None

    def __str__(self) -> str:
        if self.return_value is None:
            return "return;"
        return f"return {self.return_value};"


@dataclass
class ExpressionStatement(Statement):
    expression: Optional[Expression] = None

    def __str__(self) -> str:
        return "" if self.expression is None else str(self.expression)


@dataclass
class IntegerLiteral(Expression):
    value: int = 0

    def __str__(self) -> str:
        return str(self.value)


@dataclass
class FloatLiteral(Expression):
    value: float = 0.0

    def __str__(self) -> str:
        return str(self.value)


@dataclass
class BinaryLiteral(Expression):
    value: str = ""


@dataclass
class OctalLiteral(Expression):
    value: str = ""


@dataclass
class HexLiteral(Expression):
    value: str = ""


@dataclass
class StringLiteral(Expression):
    value: str = ""

    def __str__(self) -> str:
        return self.value


@dataclass
class BooleanLiteral(Expression):
    value: bool = False

    def __str__(self) -> str:
        return "true" if self.value else "false"


@dataclass
class NullLiteral(Expression):
    def __str__(self) -> str:
        return "null"


@dataclass
class PrefixExpression(Expression):
    operator: str = ""
    right: Optional[Expression] = None

    def __str__(self) -> str:
        return f"({self.operator}{self.right})"


@dataclass
class InfixExpression(Expression):
    left: Optional[Expression] = None
    operator: str = ""
    right: Optional[Expression] = None

    def __str__(self) -> str:
        return f"({self.left} {self.operator} {self.right})"


@dataclass
class AssignExpression(Expression):
    name: Optional[Expression] = None
    value: Optional[Expression] = None

    def __str__(self) -> str:
        return f"({self.name} = {self.value})"


@dataclass
class IfExpression(Expression):
    condition: Optional[Expression] = None
    consequence: Optional["BlockStatement"] = None
    alternative: Optional["BlockStatement"] = None


@dataclass
class BlockStatement(Statement):
    statements: List[Statement] = field(default_factory=list)

    def __str__(self) -> str:
        return "".join(str(s) for s in self.statements)


@dataclass
class FunctionLiteral(Expression):
    parameters: List[Identifier] = field(default_factory=list)
    body: Optional[BlockStatement] = None
    name: Optional[Identifier] = None

    def __str__(self) -> str:
        params = ", ".join(str(p) for p in self.parameters)
        return f"fn({params}) {self.body}"


@dataclass
class CallExpression(Expression):
    function: Optional[Expression] = None
    arguments: List[Expression] = field(default_factory=list)

    def __str__(self) -> str:
        args = ", ".join(str(a) for a in self.arguments)
        return f"{self.function}({args})"


@dataclass
class ArrayLiteral(Expression):
    elements: List[Expression] = field(default_factory=list)

    def __str__(self) -> str:
        return "[" + ", ".join(str(e) for e in self.elements) + "]"


@dataclass
class IndexExpression(Expression):
    left: Optional[Expression] = None
    index: Optional[Expression] = None

    def __str__(self) -> str:
        return f"({self.left}[{self.index}])"


@dataclass
class HashLiteral(Expression):
    # Supports dict-like maps or ordered key/value tuples produced by parser.
    pairs: Any = field(default_factory=dict)


@dataclass
class WhileStatement(Statement):
    condition: Optional[Expression] = None
    body: Optional[BlockStatement] = None


@dataclass
class ForStatement(Statement):
    initialization: Optional[Statement] = None
    condition: Optional[Expression] = None
    increment: Optional[Expression] = None
    body: Optional[BlockStatement] = None


@dataclass
class ForInStatement(Statement):
    iterator: Optional[Identifier] = None
    iterable: Optional[Expression] = None
    body: Optional[BlockStatement] = None


@dataclass
class ClassStatement(Statement):
    name: Optional[Identifier] = None
    superclass: Optional[Identifier] = None
    body: Optional[BlockStatement] = None


@dataclass
class SuperExpression(Expression):
    pass


@dataclass
class SelfExpression(Expression):
    pass


@dataclass
class NewExpression(Expression):
    cls: Optional[Expression] = None


@dataclass
class ImportStatement(Statement):
    path: Optional[StringLiteral] = None


@dataclass
class UseStatement(Statement):
    module: str = ""


@dataclass
class FromStatement(Statement):
    path: Optional[StringLiteral] = None
    imports: List[Identifier] = field(default_factory=list)


@dataclass
class TryStatement(Statement):
    try_block: Optional[BlockStatement] = None
    except_block: Optional[BlockStatement] = None
    finally_block: Optional[BlockStatement] = None


@dataclass
class RaiseStatement(Statement):
    exception: Optional[Expression] = None


@dataclass
class AssertStatement(Statement):
    condition: Optional[Expression] = None
    message: Optional[Expression] = None


@dataclass
class WithStatement(Statement):
    context: Optional[Expression] = None
    body: Optional[BlockStatement] = None


@dataclass
class YieldExpression(Expression):
    value: Optional[Expression] = None


@dataclass
class AsyncStatement(Statement):
    statement: Optional[Statement] = None


@dataclass
class AwaitExpression(Expression):
    expression: Optional[Expression] = None


@dataclass
class PassStatement(Statement):
    pass


@dataclass
class BreakStatement(Statement):
    pass


@dataclass
class ContinueStatement(Statement):
    pass


# ============================================================================
# Type Annotation Nodes
# ============================================================================

@dataclass
class TypeAnnotation(Node):
    """Base for type annotations."""
    pass


@dataclass
class SimpleType(TypeAnnotation):
    """Simple type: int, str, MyClass, etc."""
    name: str = ""


@dataclass
class GenericType(TypeAnnotation):
    """Generic type: List[int], Dict[str, int], etc."""
    base: str = ""
    type_params: List[TypeAnnotation] = field(default_factory=list)


@dataclass
class UnionType(TypeAnnotation):
    """Union type: int | str | None"""
    types: List[TypeAnnotation] = field(default_factory=list)


@dataclass
class FunctionType(TypeAnnotation):
    """Function type: (int, str) -> bool"""
    param_types: List[TypeAnnotation] = field(default_factory=list)
    return_type: Optional[TypeAnnotation] = None


@dataclass
class OptionalType(TypeAnnotation):
    """Optional type: T?"""
    inner_type: TypeAnnotation = field(default_factory=SimpleType)


# ============================================================================
# Pattern Matching Nodes  
# ============================================================================

@dataclass
class MatchExpression(Expression):
    """Match expression: match value { ... }"""
    value: Optional[Expression] = None
    cases: List["CaseClause"] = field(default_factory=list)


@dataclass
class CaseClause(Node):
    """Case in match expression."""
    pattern: Optional["Pattern"] = None
    guard: Optional[Expression] = None  # when condition
    body: Optional[Expression] = None


@dataclass
class Pattern(Node):
    """Base class for patterns."""
    pass


@dataclass
class LiteralPattern(Pattern):
    """Literal pattern: 42, "hello", true"""
    value: Optional[Expression] = None


@dataclass
class IdentifierPattern(Pattern):
    """Identifier pattern: x (binds variable)"""
    name: str = ""


@dataclass
class StructPattern(Pattern):
    """Struct pattern: Point { x, y }"""
    struct_name: str = ""
    fields: List[Tuple[str, Pattern]] = field(default_factory=list)


@dataclass
class ArrayPattern(Pattern):
    """Array pattern: [first, ...rest]"""
    elements: List[Pattern] = field(default_factory=list)
    rest: Optional[str] = None  # Rest pattern name


@dataclass
class WildcardPattern(Pattern):
    """Wildcard pattern: _"""
    pass


# ============================================================================
# Advanced Expressions
# ============================================================================

@dataclass
class RangeExpression(Expression):
    """Range: 0..10 or 0..=10"""
    start: Optional[Expression] = None
    end: Optional[Expression] = None
    inclusive: bool = False


@dataclass
class SpreadExpression(Expression):
    """Spread: ...items"""
    expression: Optional[Expression] = None


@dataclass
class PipelineExpression(Expression):
    """Pipeline: value |> func1 |> func2"""
    left: Optional[Expression] = None
    right: Optional[Expression] = None


@dataclass
class OptionalChainingExpression(Expression):
    """Optional chaining: obj?.prop?.method()"""
    object: Optional[Expression] = None
    property: str = ""


@dataclass
class NullCoalescingExpression(Expression):
    """Null coalescing: value ?? default"""
    left: Optional[Expression] = None
    right: Optional[Expression] = None


@dataclass
class LambdaExpression(Expression):
    """Lambda: x -> x + 1 or (x, y) -> x + y"""
    parameters: List[Identifier] = field(default_factory=list)
    body: Optional[Expression] = None
    is_async: bool = False


@dataclass
class ComprehensionExpression(Expression):
    """List/dict comprehension: [x*2 for x in items if x > 0]"""
    element: Optional[Expression] = None
    iterator: Optional[Identifier] = None
    iterable: Optional[Expression] = None
    condition: Optional[Expression] = None
    is_dict: bool = False  # If True, element should be key-value pair


@dataclass
class TernaryExpression(Expression):
    """Ternary: condition ? true_val : false_val"""
    condition: Optional[Expression] = None
    true_value: Optional[Expression] = None
    false_value: Optional[Expression] = None


# ============================================================================
# Advanced Declaration Statements
# ============================================================================

@dataclass
class EnumDeclaration(Statement):
    """Enum: enum Color { Red, Green, Blue }"""
    name: Optional[Identifier] = None
    variants: List["EnumVariant"] = field(default_factory=list)


@dataclass
class EnumVariant(Node):
    """Enum variant."""
    name: str = ""
    value: Optional[Expression] = None  # For explicit values
    fields: List[Tuple[str, TypeAnnotation]] = field(default_factory=list)  # For tuple variants


@dataclass
class TraitDeclaration(Statement):
    """Trait/Interface: trait Drawable { ... }"""
    name: Optional[Identifier] = None
    methods: List["MethodSignature"] = field(default_factory=list)
    supertraits: List[Identifier] = field(default_factory=list)


@dataclass
class MethodSignature(Node):
    """Method signature in trait."""
    name: str = ""
    parameters: List[Tuple[str, TypeAnnotation]] = field(default_factory=list)
    return_type: Optional[TypeAnnotation] = None


@dataclass
class ImplBlock(Statement):
    """Implementation block: impl Trait for Type { ... }"""
    trait: Optional[Identifier] = None
    type_name: Optional[Identifier] = None
    methods: List[FunctionLiteral] = field(default_factory=list)


@dataclass
class StructDeclaration(Statement):
    """Struct: struct Point { x: int, y: int }"""
    name: Optional[Identifier] = None
    fields: List["StructField"] = field(default_factory=list)


@dataclass
class StructField(Node):
    """Struct field."""
    name: str = ""
    field_type: Optional[TypeAnnotation] = None
    default_value: Optional[Expression] = None


@dataclass
class TypeAliasStatement(Statement):
    """Type alias: type StringMap = Dict[str, str]"""
    name: str = ""
    type_def: Optional[TypeAnnotation] = None


# ============================================================================
# Module and Export Statements
# ============================================================================

@dataclass
class ExportStatement(Statement):
    """Export: export { foo, bar } or export let x = 1"""
    names: List[str] = field(default_factory=list)
    statement: Optional[Statement] = None  # For export let/fn/class


@dataclass
class ModuleDeclaration(Statement):
    """Module: mod mymodule { ... }"""
    name: str = ""
    body: List[Statement] = field(default_factory=list)


@dataclass
class NamespaceDeclaration(Statement):
    """Namespace: namespace MyNamespace { ... }"""
    name: str = ""
    body: List[Statement] = field(default_factory=list)


# ============================================================================
# Advanced Control Flow
# ============================================================================

@dataclass
class LoopStatement(Statement):
    """Infinite loop: loop { ... }"""
    body: Optional[BlockStatement] = None


@dataclass
class DeferStatement(Statement):
    """Defer: defer cleanup()"""
    statement: Optional[Statement] = None


@dataclass
class SelectStatement(Statement):
    """Select for channel operations: select { case <- ch: ... }"""
    cases: List["SelectCase"] = field(default_factory=list)


@dataclass
class SelectCase(Node):
    """Case in select statement."""
    channel_op: Optional[Expression] = None
    body: Optional[BlockStatement] = None


@dataclass
class GuardStatement(Statement):
    """Guard: guard condition else { return }"""
    condition: Optional[Expression] = None
    else_block: Optional[BlockStatement] = None


# ============================================================================
# Decorator and Macro Nodes
# ============================================================================

@dataclass
class DecoratorExpression(Expression):
    """Decorator: @decorator or @decorator(arg1, arg2)"""
    name: str = ""
    arguments: List[Expression] = field(default_factory=list)


@dataclass
class MacroInvocation(Expression):
    """Macro invocation: my_macro!(args)"""
    name: str = ""
    arguments: List[Expression] = field(default_factory=list)


@dataclass
class MacroDefinition(Statement):
    """Macro definition: macro my_macro { ... }"""
    name: str = ""
    rules: List["MacroRule"] = field(default_factory=list)


@dataclass
class MacroRule(Node):
    """Macro rule."""
    pattern: str = ""
    expansion: str = ""


# ============================================================================
# Metaprogramming Nodes
# ============================================================================

@dataclass
class ComptimeExpression(Expression):
    """Compile-time expression: comptime { ... }"""
    expression: Optional[Expression] = None


@dataclass
class StaticAssertStatement(Statement):
    """Static assert: static_assert(condition, message)"""
    condition: Optional[Expression] = None
    message: Optional[Expression] = None


@dataclass
class UnsafeBlock(Statement):
    """Unsafe block: unsafe { ... }"""
    body: Optional[BlockStatement] = None


# Stable aliases for older integrations.
StatementNode = Statement
ExpressionNode = Expression
ProgramNode = Program


@dataclass
class DynamicNode(Node):
    """
    Extension node for future modules/features.
    Use this when parser/plugins add constructs without changing core classes.
    """

    kind: str = ""
    payload: Dict[str, Any] = field(default_factory=dict)


NODE_REGISTRY: Dict[str, Type[Node]] = {}


def register_node(name: str, cls: Type[Node]) -> None:
    NODE_REGISTRY[name] = cls


def create_node(name: str, **kwargs) -> Node:
    cls = NODE_REGISTRY.get(name)
    if cls is None:
        return DynamicNode(kind=name, payload=dict(kwargs))
    return cls(**kwargs)


def node_to_dict(node: Any) -> Any:
    if is_dataclass(node):
        out: Dict[str, Any] = {"_type": node.__class__.__name__}
        for f in fields(node):
            out[f.name] = node_to_dict(getattr(node, f.name))
        return out
    if isinstance(node, list):
        return [node_to_dict(v) for v in node]
    if isinstance(node, dict):
        return {str(k): node_to_dict(v) for k, v in node.items()}
    return node

__all__ = [
    # Core
    "Node",
    "Statement",
    "Expression",
    "Program",
    "SourceLocation",
    "NodeVisitor",
    
    # Basic nodes
    "Identifier",
    "LetStatement",
    "ReturnStatement",
    "ExpressionStatement",
    
    # Literals
    "IntegerLiteral",
    "FloatLiteral",
    "BinaryLiteral",
    "OctalLiteral",
    "HexLiteral",
    "StringLiteral",
    "BooleanLiteral",
    "NullLiteral",
    
    # Expressions
    "PrefixExpression",
    "InfixExpression",
    "AssignExpression",
    "IfExpression",
    "CallExpression",
    "IndexExpression",
    "RangeExpression",
    "SpreadExpression",
    "PipelineExpression",
    "OptionalChainingExpression",
    "NullCoalescingExpression",
    "LambdaExpression",
    "ComprehensionExpression",
    "TernaryExpression",
    "YieldExpression",
    "AwaitExpression",
    "DecoratorExpression",
    "MacroInvocation",
    "ComptimeExpression",
    
    # Collections
    "BlockStatement",
    "ArrayLiteral",
    "HashLiteral",
    "FunctionLiteral",
    
    # Control Flow
    "WhileStatement",
    "ForStatement",
    "ForInStatement",
    "LoopStatement",
    "BreakStatement",
    "ContinueStatement",
    "PassStatement",
    "DeferStatement",
    
    # OOP
    "ClassStatement",
    "StructDeclaration",
    "StructField",
    "EnumDeclaration",
    "EnumVariant",
    "TraitDeclaration",
    "MethodSignature",
    "ImplBlock",
    "SuperExpression",
    "SelfExpression",
    "NewExpression",
    
    # Modules
    "ImportStatement",
    "UseStatement",
    "FromStatement",
    "ExportStatement",
    "ModuleDeclaration",
    "NamespaceDeclaration",
    
    # Error Handling
    "TryStatement",
    "RaiseStatement",
    "AssertStatement",
    "StaticAssertStatement",
    
    # Async/Concurrency
    "WithStatement",
    "AsyncStatement",
    "SelectStatement",
    "SelectCase",
    "GuardStatement",
    "UnsafeBlock",
    
    # Pattern Matching
    "MatchExpression",
    "CaseClause",
    "Pattern",
    "LiteralPattern",
    "IdentifierPattern",
    "StructPattern",
    "ArrayPattern",
    "WildcardPattern",
    
    # Type System
    "TypeAnnotation",
    "SimpleType", 
    "GenericType",
    "UnionType",
    "FunctionType",
    "OptionalType",
    "TypeAliasStatement",
    
    # Macros
    "MacroDefinition",
    "MacroRule",
    
    # Compatibility
    "StatementNode",
    "ExpressionNode",
    "ProgramNode",
    "DynamicNode",
    
    # Utilities
    "NODE_REGISTRY",
    "register_node",
    "create_node",
    "node_to_dict",
    "walk",
    "find_nodes",
    "transform",
]


# ============================================================================
# AST Traversal Utilities
# ============================================================================

def walk(node: Node, callback: Callable[[Node], None]) -> None:
    """
    Walk the AST and call callback on each node.
    
    Example:
        def print_node(n):
            print(type(n).__name__)
        walk(ast, print_node)
    """
    callback(node)
    
    if isinstance(node, (list, tuple)):
        for item in node:
            if isinstance(item, Node):
                walk(item, callback)
    elif is_dataclass(node):
        for f in fields(node):
            value = getattr(node, f.name)
            if isinstance(value, Node):
                walk(value, callback)
            elif isinstance(value, (list, tuple)):
                for item in value:
                    if isinstance(item, Node):
                        walk(item, callback)


def find_nodes(node: Node, node_type: Type[Node]) -> List[Node]:
    """
    Find all nodes of a specific type in the AST.
    
    Example:
        all_functions = find_nodes(ast, FunctionLiteral)
    """
    results = []
    
    def collector(n: Node):
        if isinstance(n, node_type):
            results.append(n)
    
    walk(node, collector)
    return results


def transform(node: Node, transformer: Callable[[Node], Node]) -> Node:
    """
    Transform AST by applying a function to each node.
    
    The transformer function receives a node and returns a (potentially modified) node.
    """
    # Transform current node
    node = transformer(node)
    
    # Transform children
    if is_dataclass(node):
        for f in fields(node):
            value = getattr(node, f.name)
            if isinstance(value, Node):
                setattr(node, f.name, transform(value, transformer))
            elif isinstance(value, list):
                setattr(node, f.name, [
                    transform(item, transformer) if isinstance(item, Node) else item
                    for item in value
                ])
    
    return node
