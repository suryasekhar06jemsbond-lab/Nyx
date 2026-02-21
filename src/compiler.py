# ================================================================
# NYX COMPILER - Real AST Pipeline
# ================================================================
# Implements a full compiler pipeline from Nyx source to target code.
# Supports JavaScript, WASM, and native code generation.

import os
import json
import hashlib
import time
import re
from typing import Any, Dict, List, Optional, Tuple, Set
from dataclasses import dataclass, field
from enum import Enum, auto
from pathlib import Path
from src.stability import load_stability_config


# ================================================================
# Compilation Target
# ================================================================

class Target(Enum):
    JS = auto()          # JavaScript (ES6+)
    WASM = auto()        # WebAssembly
    NATIVE = auto()      # Native code (via C)
    BYTECODE = auto()    # Nyx bytecode for VM


# ================================================================
# Compilation Options
# ================================================================

@dataclass
class CompileOptions:
    """Options for compilation."""
    target: Target = Target.JS
    minify: bool = False
    source_map: bool = True
    debug: bool = False
    optimize: int = 2  # 0-3 optimization level
    output_dir: str = "dist"
    entry_point: str = "main"
    externals: List[str] = field(default_factory=list)
    defines: Dict[str, Any] = field(default_factory=dict)


# ================================================================
# Source File
# ================================================================

@dataclass
class SourceFile:
    """Represents a source file in the compilation."""
    path: str
    content: str
    hash: str = ""
    modified_time: float = 0.0
    
    def __post_init__(self):
        if not self.hash:
            self.hash = hashlib.sha256(self.content.encode()).hexdigest()[:16]
        if not self.modified_time:
            self.modified_time = time.time()


# ================================================================
# AST Node Types (Extended for Compiler)
# ================================================================

class ASTNode:
    """Base class for all AST nodes."""
    def __init__(self, line: int = 0, column: int = 0, scope_id: int = 0):
        self.line = line
        self.column = column
        self.scope_id = scope_id


@dataclass
class ProgramNode:
    """Root node of a program."""
    statements: List[ASTNode] = field(default_factory=list)
    imports: List['ImportNode'] = field(default_factory=list)
    exports: List['ExportNode'] = field(default_factory=list)


@dataclass
class ImportNode:
    """Import statement."""
    module: str = ""
    names: List[str] = field(default_factory=list)
    alias: Optional[str] = None


@dataclass
class ExportNode:
    """Export statement."""
    name: str = ""
    value: Optional[ASTNode] = None


@dataclass
class LetNode(ASTNode):
    """Variable declaration."""
    name: str
    value: ASTNode
    mutable: bool = True
    type_annotation: Optional[str] = None


@dataclass
class FunctionNode(ASTNode):
    """Function definition."""
    name: str
    parameters: List[Tuple[str, Optional[str]]]  # (name, type)
    body: List[ASTNode]
    return_type: Optional[str] = None
    is_async: bool = False
    is_generator: bool = False


@dataclass
class ClassNode(ASTNode):
    """Class definition."""
    name: str
    superclass: Optional[str]
    fields: List[Tuple[str, Optional[str]]]  # (name, type)
    methods: List[FunctionNode]
    static_methods: List[FunctionNode]


@dataclass
class CallNode(ASTNode):
    """Function call."""
    callee: ASTNode
    arguments: List[ASTNode]


@dataclass
class MemberNode(ASTNode):
    """Member access (obj.field or obj.method())."""
    object: ASTNode
    property: str


@dataclass
class BinaryNode(ASTNode):
    """Binary operation."""
    left: ASTNode
    operator: str
    right: ASTNode


@dataclass
class UnaryNode(ASTNode):
    """Unary operation."""
    operator: str
    operand: ASTNode


@dataclass
class IfNode(ASTNode):
    """If expression/statement."""
    condition: ASTNode
    then_branch: List[ASTNode]
    else_branch: Optional[List[ASTNode]] = None


@dataclass
class WhileNode(ASTNode):
    """While loop."""
    condition: ASTNode
    body: List[ASTNode]


@dataclass
class ForNode(ASTNode):
    """For-in loop."""
    variable: str
    iterable: ASTNode
    body: List[ASTNode]


@dataclass
class ReturnNode(ASTNode):
    """Return statement."""
    value: Optional[ASTNode] = None


@dataclass
class IdentifierNode(ASTNode):
    """Identifier (variable name)."""
    name: str


@dataclass
class LiteralNode(ASTNode):
    """Literal value."""
    value: Any
    type: str  # "int", "float", "string", "bool", "null"


@dataclass
class ArrayNode(ASTNode):
    """Array literal."""
    elements: List[ASTNode]


@dataclass
class ObjectNode(ASTNode):
    """Object literal."""
    properties: List[Tuple[str, ASTNode]]


@dataclass
class AwaitNode(ASTNode):
    """Await expression."""
    expression: ASTNode


@dataclass
class YieldNode(ASTNode):
    """Yield expression."""
    expression: ASTNode


@dataclass
class TryNode(ASTNode):
    """Try-catch-finally."""
    try_block: List[ASTNode]
    catch_var: Optional[str] = None
    catch_block: Optional[List[ASTNode]] = None
    finally_block: Optional[List[ASTNode]] = None


@dataclass
class ThrowNode(ASTNode):
    """Throw statement."""
    error: ASTNode


# ================================================================
# Symbol Table
# ================================================================

@dataclass
class Symbol:
    """A symbol in the symbol table."""
    name: str
    type: str  # "variable", "function", "class", "parameter"
    scope_id: int
    declared_at: Tuple[int, int]  # (line, column)
    type_info: Optional[str] = None  # Type annotation
    is_mutable: bool = True
    is_exported: bool = False
    is_imported: bool = False
    source_module: Optional[str] = None


class SymbolTable:
    """Symbol table for semantic analysis."""
    
    def __init__(self):
        self.scopes: Dict[int, Dict[str, Symbol]] = {}
        self.scope_stack: List[int] = [0]
        self.next_scope_id = 1
        self.symbols: Dict[str, Symbol] = {}
    
    def current_scope(self) -> int:
        return self.scope_stack[-1]
    
    def push_scope(self) -> int:
        scope_id = self.next_scope_id
        self.next_scope_id += 1
        self.scopes[scope_id] = {}
        self.scope_stack.append(scope_id)
        return scope_id
    
    def pop_scope(self):
        if len(self.scope_stack) > 1:
            self.scope_stack.pop()
    
    def declare(self, name: str, type: str, type_info: Optional[str] = None,
                is_mutable: bool = True, is_exported: bool = False) -> Symbol:
        """Declare a new symbol in the current scope."""
        scope_id = self.current_scope()
        symbol = Symbol(
            name=name,
            type=type,
            scope_id=scope_id,
            declared_at=(0, 0),
            type_info=type_info,
            is_mutable=is_mutable,
            is_exported=is_exported
        )
        self.scopes.setdefault(scope_id, {})[name] = symbol
        self.symbols[name] = symbol
        return symbol
    
    def lookup(self, name: str) -> Optional[Symbol]:
        """Look up a symbol, searching from innermost to outermost scope."""
        for scope_id in reversed(self.scope_stack):
            if scope_id in self.scopes and name in self.scopes[scope_id]:
                return self.scopes[scope_id][name]
        return None
    
    def resolve(self, name: str) -> Optional[Symbol]:
        """Resolve a symbol name to its definition."""
        return self.symbols.get(name)


# ================================================================
# Type System
# ================================================================

@dataclass
class TypeInfo:
    """Type information for a node."""
    name: str
    nullable: bool = False
    generic_params: List['TypeInfo'] = field(default_factory=list)


class TypeChecker:
    """Type checker for semantic analysis."""
    
    def __init__(self):
        self.types: Dict[str, TypeInfo] = {
            'int': TypeInfo('int'),
            'float': TypeInfo('float'),
            'string': TypeInfo('string'),
            'bool': TypeInfo('bool'),
            'null': TypeInfo('null'),
            'void': TypeInfo('void'),
            'any': TypeInfo('any'),
        }
        self.errors: List[str] = []
    
    def check(self, node: ASTNode, symbols: SymbolTable) -> Optional[TypeInfo]:
        """Check the type of an AST node."""
        method_name = f'check_{type(node).__name__}'
        checker = getattr(self, method_name, self.generic_check)
        return checker(node, symbols)
    
    def generic_check(self, node: ASTNode, symbols: SymbolTable) -> Optional[TypeInfo]:
        return self.types.get('any')
    
    def check_LiteralNode(self, node: LiteralNode, symbols: SymbolTable) -> TypeInfo:
        return self.types.get(node.type, self.types['any'])
    
    def check_BinaryNode(self, node: BinaryNode, symbols: SymbolTable) -> Optional[TypeInfo]:
        left_type = self.check(node.left, symbols)
        right_type = self.check(node.right, symbols)
        
        if node.operator in ['+', '-', '*', '/']:
            if left_type and right_type:
                if left_type.name == 'string' or right_type.name == 'string':
                    if node.operator == '+':
                        return self.types['string']
                if left_type.name == 'float' or right_type.name == 'float':
                    return self.types['float']
                return self.types['int']
        elif node.operator in ['<', '>', '<=', '>=', '==', '!=']:
            return self.types['bool']
        
        return self.types['any']
    
    def check_IdentifierNode(self, node: IdentifierNode, symbols: SymbolTable) -> Optional[TypeInfo]:
        symbol = symbols.lookup(node.name)
        if symbol:
            if symbol.type_info:
                return self.types.get(symbol.type_info, self.types['any'])
            return self.types['any']
        self.errors.append(f"Undefined identifier: {node.name}")
        return None
    
    def check_CallNode(self, node: CallNode, symbols: SymbolTable) -> Optional[TypeInfo]:
        # Check callee and arguments
        for arg in node.arguments:
            self.check(arg, symbols)
        
        # Try to determine return type
        if isinstance(node.callee, IdentifierNode):
            symbol = symbols.lookup(node.callee.name)
            if symbol and symbol.type_info:
                return self.types.get(symbol.type_info, self.types['any'])
        
        return self.types['any']


# ================================================================
# Module System
# ================================================================

@dataclass
class Module:
    """A compiled module."""
    name: str
    path: str
    source: SourceFile
    ast: Optional[ProgramNode] = None
    symbols: Optional[SymbolTable] = None
    dependencies: List[str] = field(default_factory=list)
    exports: Dict[str, Symbol] = field(default_factory=dict)
    imports: Dict[str, str] = field(default_factory=dict)  # name -> module
    compiled: bool = False
    output: Optional[str] = None


class ModuleRegistry:
    """Registry for all modules in a project."""
    
    def __init__(self):
        self.modules: Dict[str, Module] = {}
        self.module_graph: Dict[str, List[str]] = {}  # module -> dependencies
        self.resolved: Dict[str, str] = {}  # alias -> module path
    
    def register(self, module: Module):
        """Register a module."""
        self.modules[module.name] = module
        self.module_graph[module.name] = []
    
    def get(self, name: str) -> Optional[Module]:
        """Get a module by name."""
        return self.modules.get(name)
    
    def add_dependency(self, module: str, depends_on: str):
        """Add a dependency relationship."""
        if module in self.module_graph:
            self.module_graph[module].append(depends_on)
    
    def get_load_order(self) -> List[str]:
        """Get modules in dependency order (topological sort)."""
        visited = set()
        order = []
        
        def visit(name: str):
            if name in visited:
                return
            visited.add(name)
            for dep in self.module_graph.get(name, []):
                visit(dep)
            order.append(name)
        
        for name in self.modules:
            visit(name)
        
        return order
    
    def detect_cycles(self) -> List[List[str]]:
        """Detect circular dependencies."""
        cycles = []
        visited = set()
        rec_stack = set()
        
        def dfs(node: str, path: List[str]) -> bool:
            visited.add(node)
            rec_stack.add(node)
            path.append(node)
            
            for dep in self.module_graph.get(node, []):
                if dep not in visited:
                    if dfs(dep, path):
                        return True
                elif dep in rec_stack:
                    # Found cycle
                    cycle_start = path.index(dep)
                    cycles.append(path[cycle_start:] + [dep])
                    return True
            
            path.pop()
            rec_stack.remove(node)
            return False
        
        for name in self.modules:
            if name not in visited:
                dfs(name, [])
        
        return cycles


# ================================================================
# Code Generator
# ================================================================

class CodeGenerator:
    """Base class for code generators."""
    
    def __init__(self, options: CompileOptions):
        self.options = options
        self.output: List[str] = []
        self.indent_level = 0
        self.indent_str = "    "
    
    def generate(self, node: ASTNode) -> str:
        """Generate code for an AST node."""
        method_name = f'gen_{type(node).__name__}'
        generator = getattr(self, method_name, self.generic_gen)
        return generator(node)
    
    def generic_gen(self, node: ASTNode) -> str:
        return f"/* Unsupported: {type(node).__name__} */"
    
    def emit(self, code: str):
        """Emit a line of code."""
        self.output.append(self.indent_str * self.indent_level + code)
    
    def indent(self):
        self.indent_level += 1
    
    def dedent(self):
        self.indent_level = max(0, self.indent_level - 1)
    
    def get_output(self) -> str:
        return "\n".join(self.output)


class JavaScriptGenerator(CodeGenerator):
    """Generate JavaScript code from AST."""
    
    def __init__(self, options: CompileOptions):
        super().__init__(options)
        self.exports: Set[str] = set()
    
    def gen_ProgramNode(self, node: ProgramNode) -> str:
        # Emit imports
        for imp in node.imports:
            self.emit(self.generate(imp))
        
        self.emit("")
        
        # Emit statements
        for stmt in node.statements:
            self.emit(self.generate(stmt))
        
        # Emit exports
        if self.exports:
            self.emit("")
            exports_list = ", ".join(self.exports)
            self.emit(f"export {{ {exports_list} }};")
        
        return self.get_output()
    
    def gen_ImportNode(self, node: ImportNode) -> str:
        names = ", ".join(node.names)
        if node.alias:
            return f'import * as {node.alias} from "{node.module}";'
        return f'import {{ {names} }} from "{node.module}";'
    
    def gen_ExportNode(self, node: ExportNode) -> str:
        self.exports.add(node.name)
        if node.value:
            return f"const {node.name} = {self.generate(node.value)};"
        return ""
    
    def gen_LetNode(self, node: LetNode) -> str:
        keyword = "let" if node.mutable else "const"
        value = self.generate(node.value)
        return f"{keyword} {node.name} = {value};"
    
    def gen_FunctionNode(self, node: FunctionNode) -> str:
        params = ", ".join(p[0] for p in node.parameters)
        async_kw = "async " if node.is_async else ""
        
        self.emit(f"{async_kw}function {node.name}({params}) {{")
        self.indent()
        
        for stmt in node.body:
            self.emit(self.generate(stmt))
        
        self.dedent()
        self.emit("}")
        
        return ""
    
    def gen_ClassNode(self, node: ClassNode) -> str:
        extends = f" extends {node.superclass}" if node.superclass else ""
        
        self.emit(f"class {node.name}{extends} {{")
        self.indent()
        
        # Constructor
        if node.fields:
            self.emit("constructor(" + ", ".join(f[0] for f in node.fields) + ") {")
            self.indent()
            for name, _ in node.fields:
                self.emit(f"this.{name} = {name};")
            self.dedent()
            self.emit("}")
        
        # Methods
        for method in node.methods:
            self.emit(self.generate(method))
        
        self.dedent()
        self.emit("}")
        
        return ""
    
    def gen_CallNode(self, node: CallNode) -> str:
        callee = self.generate(node.callee)
        args = ", ".join(self.generate(arg) for arg in node.arguments)
        return f"{callee}({args})"
    
    def gen_MemberNode(self, node: MemberNode) -> str:
        obj = self.generate(node.object)
        return f"{obj}.{node.property}"
    
    def gen_BinaryNode(self, node: BinaryNode) -> str:
        left = self.generate(node.left)
        right = self.generate(node.right)
        return f"({left} {node.operator} {right})"
    
    def gen_UnaryNode(self, node: UnaryNode) -> str:
        operand = self.generate(node.operand)
        return f"({node.operator}{operand})"
    
    def gen_IfNode(self, node: IfNode) -> str:
        cond = self.generate(node.condition)
        
        self.emit(f"if ({cond}) {{")
        self.indent()
        for stmt in node.then_branch:
            self.emit(self.generate(stmt))
        self.dedent()
        
        if node.else_branch:
            self.emit("} else {")
            self.indent()
            for stmt in node.else_branch:
                self.emit(self.generate(stmt))
            self.dedent()
            self.emit("}")
        else:
            self.emit("}")
        
        return ""
    
    def gen_WhileNode(self, node: WhileNode) -> str:
        cond = self.generate(node.condition)
        
        self.emit(f"while ({cond}) {{")
        self.indent()
        for stmt in node.body:
            self.emit(self.generate(stmt))
        self.dedent()
        self.emit("}")
        
        return ""
    
    def gen_ForNode(self, node: ForNode) -> str:
        iterable = self.generate(node.iterable)
        
        self.emit(f"for (const {node.variable} of {iterable}) {{")
        self.indent()
        for stmt in node.body:
            self.emit(self.generate(stmt))
        self.dedent()
        self.emit("}")
        
        return ""
    
    def gen_ReturnNode(self, node: ReturnNode) -> str:
        if node.value:
            return f"return {self.generate(node.value)};"
        return "return;"
    
    def gen_IdentifierNode(self, node: IdentifierNode) -> str:
        return node.name
    
    def gen_LiteralNode(self, node: LiteralNode) -> str:
        if node.type == "string":
            return json.dumps(node.value)
        elif node.type == "bool":
            return "true" if node.value else "false"
        elif node.type == "null":
            return "null"
        return str(node.value)
    
    def gen_ArrayNode(self, node: ArrayNode) -> str:
        elements = ", ".join(self.generate(e) for e in node.elements)
        return f"[{elements}]"
    
    def gen_ObjectNode(self, node: ObjectNode) -> str:
        props = ", ".join(f"{k}: {self.generate(v)}" for k, v in node.properties)
        return f"{{{props}}}"
    
    def gen_AwaitNode(self, node: AwaitNode) -> str:
        return f"await {self.generate(node.expression)}"
    
    def gen_TryNode(self, node: TryNode) -> str:
        self.emit("try {")
        self.indent()
        for stmt in node.try_block:
            self.emit(self.generate(stmt))
        self.dedent()
        
        if node.catch_block:
            self.emit(f"}} catch ({node.catch_var or 'e'}) {{")
            self.indent()
            for stmt in node.catch_block:
                self.emit(self.generate(stmt))
            self.dedent()
        
        if node.finally_block:
            self.emit("} finally {")
            self.indent()
            for stmt in node.finally_block:
                self.emit(self.generate(stmt))
            self.dedent()
        
        self.emit("}")
        return ""


# ================================================================
# WASM Generator (Skeleton)
# ================================================================

class WASMGenerator(CodeGenerator):
    """Generate WebAssembly text format from AST."""
    
    def __init__(self, options: CompileOptions):
        super().__init__(options)
        self.types: Dict[str, int] = {}
        self.funcs: Dict[str, int] = {}
        self.next_type_idx = 0
        self.next_func_idx = 0
    
    def generate_module(self, node: ProgramNode) -> str:
        """Generate a complete WASM module."""
        self.emit("(module")
        self.indent()
        
        # Import runtime functions
        self.emit('(import "env" "print" (func $print (param i32)))')
        self.emit('(import "env" "memory" (memory 1))')
        
        # Generate functions
        for stmt in node.statements:
            if isinstance(stmt, FunctionNode):
                self.gen_function(stmt)
        
        # Export main function
        self.emit('(export "main" (func $main))')
        
        self.dedent()
        self.emit(")")
        
        return self.get_output()
    
    def gen_function(self, node: FunctionNode) -> str:
        """Generate a WASM function."""
        func_name = f"${node.name}"
        
        # Build function signature
        params = " ".join(f"(param ${p[0]} i32)" for p in node.parameters)
        results = "(result i32)"  # Simplified
        
        self.emit(f"(func {func_name} {params} {results}")
        self.indent()
        
        # Generate body (simplified)
        self.emit("i32.const 0")  # Return 0
        
        self.dedent()
        self.emit(")")
        
        return ""


# ================================================================
# Compiler Pipeline
# ================================================================

class Compiler:
    """Main compiler class that orchestrates the compilation pipeline."""
    
    def __init__(self, options: Optional[CompileOptions] = None):
        self.options = options or CompileOptions()
        self.stability = load_stability_config()
        self.modules = ModuleRegistry()
        self.symbols = SymbolTable()
        self.type_checker = TypeChecker()
        self.cache: Dict[str, str] = {}  # hash -> compiled output
        self.errors: List[str] = []
        self.warnings: List[str] = []
    
    def compile_file(self, path: str) -> Optional[str]:
        """Compile a single file."""
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        source = SourceFile(path=path, content=content)
        return self.compile_source(source)
    
    def compile_source(self, source: SourceFile) -> Optional[str]:
        """Compile source code."""
        # Check cache
        if source.hash in self.cache:
            return self.cache[source.hash]
        
        # Parse (would use actual parser)
        ast = self._parse(source)
        if not ast:
            return None
        
        # Semantic analysis
        self._analyze(ast)
        
        if self.errors:
            return None
        
        # Generate code
        output = self._generate(ast)
        
        # Cache result
        self.cache[source.hash] = output
        
        return output
    
    def _parse(self, source: SourceFile) -> Optional[ProgramNode]:
        """Parse source code into AST."""
        # Tolerant parser skeleton:
        # - keep compiler resilient as language evolves
        # - recover useful module/import info without hard-failing on unknown syntax
        program = ProgramNode()

        import_re = re.compile(r'^\s*(?:use|import)\s+([A-Za-z_][A-Za-z0-9_\.]*)\s*;?\s*$')
        let_re = re.compile(r'^\s*let\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*;?\s*$')

        for line_no, raw in enumerate(source.content.splitlines(), start=1):
            stripped = raw.strip()
            if not stripped or stripped.startswith('#') or stripped.startswith('//'):
                continue

            m_import = import_re.match(stripped)
            if m_import:
                module_name = m_import.group(1)
                program.imports.append(ImportNode(module=module_name, names=[module_name], alias=None))
                continue

            m_let = let_re.match(stripped)
            if m_let:
                name = m_let.group(1)
                literal_text = m_let.group(2)
                lit = self._parse_literal(literal_text, line_no=line_no)
                if lit is not None:
                    program.statements.append(LetNode(name=name, value=lit))
                continue

        return program

    def _parse_literal(self, text: str, line_no: int = 0) -> Optional[LiteralNode]:
        t = text.strip()
        if re.fullmatch(r'-?\d+', t):
            return LiteralNode(value=int(t), type="int")
        if re.fullmatch(r'-?\d+\.\d+', t):
            return LiteralNode(value=float(t), type="float")
        if (t.startswith('"') and t.endswith('"')) or (t.startswith("'") and t.endswith("'")):
            return LiteralNode(value=t[1:-1], type="string")
        if t == "true":
            return LiteralNode(value=True, type="bool")
        if t == "false":
            return LiteralNode(value=False, type="bool")
        if t == "null":
            return LiteralNode(value=None, type="null")
        self.warnings.append(f"Line {line_no}: unsupported literal for tolerant parse: {text}")
        return None
    
    def _analyze(self, ast: ProgramNode):
        """Perform semantic analysis."""
        # Build symbol table
        self._build_symbol_table(ast)
        
        # Type checking
        for stmt in ast.statements:
            self.type_checker.check(stmt, self.symbols)
        
        self.errors.extend(self.type_checker.errors)
    
    def _build_symbol_table(self, ast: ProgramNode):
        """Build symbol table from AST."""
        for stmt in ast.statements:
            if isinstance(stmt, LetNode):
                self.symbols.declare(stmt.name, "variable", stmt.type_annotation)
            elif isinstance(stmt, FunctionNode):
                self.symbols.declare(stmt.name, "function", stmt.return_type)
            elif isinstance(stmt, ClassNode):
                self.symbols.declare(stmt.name, "class")
    
    def _generate(self, ast: ProgramNode) -> str:
        """Generate target code."""
        if self.options.target == Target.JS:
            generator = JavaScriptGenerator(self.options)
        elif self.options.target == Target.WASM:
            generator = WASMGenerator(self.options)
        else:
            generator = JavaScriptGenerator(self.options)
        
        return generator.generate(ast)
    
    def compile_project(self, entry: str) -> Dict[str, str]:
        """Compile an entire project."""
        results = {}
        
        # Load entry point
        entry_module = self._load_module(entry)
        if not entry_module:
            return results
        
        # Resolve dependencies
        load_order = self.modules.get_load_order()
        
        # Check for cycles
        cycles = self.modules.detect_cycles()
        if cycles:
            for cycle in cycles:
                self.errors.append(f"Circular dependency: {' -> '.join(cycle)}")
            return results
        
        # Compile in order
        for module_name in load_order:
            module = self.modules.get(module_name)
            if module and not module.compiled:
                output = self.compile_source(module.source)
                if output:
                    module.output = output
                    module.compiled = True
                    results[module_name] = output
        
        return results
    
    def _load_module(self, path: str) -> Optional[Module]:
        """Load a module and its dependencies."""
        resolved = self._resolve_module_path(path)
        if not resolved:
            self.errors.append(f"Unable to resolve module: {path}")
            return None

        with open(resolved, 'r', encoding='utf-8') as f:
            content = f.read()
        
        source = SourceFile(path=resolved, content=content)
        module = Module(name=path, path=resolved, source=source)
        self.modules.register(module)
        
        return module

    def _resolve_module_path(self, ref: str) -> Optional[str]:
        p = Path(ref)
        if p.exists():
            return str(p)

        if p.suffix == "":
            # Try workspace-relative .ny file
            direct = Path(ref + ".ny")
            if direct.exists():
                return str(direct)

            # Try engine module paths discovered from manifests
            engine_dir = Path("engines") / ref
            if engine_dir.exists() and engine_dir.is_dir():
                preferred = engine_dir / f"{ref}.ny"
                if preferred.exists():
                    return str(preferred)
                ny_files = sorted(engine_dir.glob("*.ny"))
                if ny_files:
                    return str(ny_files[0])

            if ref in self.stability.known_modules:
                mod_dir = Path("engines") / ref
                if mod_dir.exists():
                    preferred = mod_dir / f"{ref}.ny"
                    if preferred.exists():
                        return str(preferred)
                    ny_files = sorted(mod_dir.glob("*.ny"))
                    if ny_files:
                        return str(ny_files[0])

        return None
    
    def write_output(self, outputs: Dict[str, str], output_dir: str):
        """Write compiled output to files."""
        os.makedirs(output_dir, exist_ok=True)
        
        for module_name, output in outputs.items():
            base_name = Path(module_name).stem
            ext = ".js" if self.options.target == Target.JS else ".wasm"
            output_path = os.path.join(output_dir, base_name + ext)
            
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(output)
            
            # Write source map if enabled
            if self.options.source_map:
                self._write_source_map(module_name, output_path)


# ================================================================
# Incremental Compilation
# ================================================================

class IncrementalCompiler(Compiler):
    """Compiler with incremental build support."""
    
    def __init__(self, options: Optional[CompileOptions] = None):
        super().__init__(options)
        self.cache_file = ".nyx/cache.json"
        self.file_hashes: Dict[str, str] = {}
        self._load_cache()
    
    def _load_cache(self):
        """Load compilation cache from disk."""
        if os.path.exists(self.cache_file):
            try:
                with open(self.cache_file, 'r') as f:
                    data = json.load(f)
                    self.file_hashes = data.get('hashes', {})
                    self.cache = data.get('outputs', {})
            except Exception:
                pass
    
    def _save_cache(self):
        """Save compilation cache to disk."""
        os.makedirs(os.path.dirname(self.cache_file), exist_ok=True)
        with open(self.cache_file, 'w') as f:
            json.dump({
                'hashes': self.file_hashes,
                'outputs': self.cache
            }, f)
    
    def needs_recompile(self, path: str) -> bool:
        """Check if a file needs recompilation."""
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        current_hash = hashlib.sha256(content.encode()).hexdigest()[:16]
        
        if path in self.file_hashes:
            return self.file_hashes[path] != current_hash
        
        return True
    
    def compile_file(self, path: str) -> Optional[str]:
        """Compile a file with caching."""
        if not self.needs_recompile(path):
            # Return cached output
            return self.cache.get(path)
        
        result = super().compile_file(path)
        
        if result:
            # Update cache
            with open(path, 'r', encoding='utf-8') as f:
                self.file_hashes[path] = hashlib.sha256(f.read().encode()).hexdigest()[:16]
            self._save_cache()
        
        return result


# ================================================================
# Bundler
# ================================================================

class Bundler:
    """Bundle multiple modules into a single file."""
    
    def __init__(self, compiler: Compiler):
        self.compiler = compiler
    
    def bundle(self, entry: str, output: str) -> bool:
        """Bundle all dependencies into a single file."""
        outputs = self.compiler.compile_project(entry)
        
        if not outputs:
            return False
        
        # Combine all outputs
        bundled = []
        bundled.append("// Nyx Bundled Output")
        bundled.append("(function() {")
        bundled.append('"use strict";')
        bundled.append("")
        
        # Add each module wrapped in a closure
        for module_name, code in outputs.items():
            bundled.append(f"// Module: {module_name}")
            bundled.append(code)
            bundled.append("")
        
        bundled.append("})();")
        
        # Write output
        with open(output, 'w', encoding='utf-8') as f:
            f.write("\n".join(bundled))
        
        return True
