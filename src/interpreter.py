from __future__ import annotations

API_VERSION = "1.0.0"

from dataclasses import dataclass
from typing import Any, Callable, Dict, List, Optional

from src.ast_nodes import (
    ArrayLiteral,
    AssignExpression,
    BlockStatement,
    BooleanLiteral,
    CallExpression,
    ExpressionStatement,
    FloatLiteral,
    FunctionLiteral,
    Identifier,
    IfExpression,
    InfixExpression,
    IntegerLiteral,
    LetStatement,
    NullLiteral,
    HashLiteral,
    IndexExpression,
    WhileStatement,
    ForStatement,
    ForInStatement,
    BreakStatement,
    ContinueStatement,
    PrefixExpression,
    Program,
    ImportStatement,
    UseStatement,
    FromStatement,
    ReturnStatement,
    StringLiteral,
    ClassStatement,
    NewExpression,
    SelfExpression,
)


class _Null:
    def __repr__(self) -> str:
        return "null"


NULL = _Null()


class ReturnSignal(Exception):
    def __init__(self, value: Any):
        self.value = value


class Environment:
    def __init__(self, outer: Optional["Environment"] = None):
        self.store: Dict[str, Any] = {}
        self.outer = outer

    def define(self, name: str, value: Any) -> Any:
        self.store[name] = value
        return value

    def set(self, name: str, value: Any) -> Any:
        if name in self.store:
            self.store[name] = value
            return value
        if self.outer is not None:
            return self.outer.set(name, value)
        self.store[name] = value
        return value

    def get(self, name: str) -> Any:
        if name in self.store:
            return self.store[name]
        if self.outer is not None:
            return self.outer.get(name)
        raise NameError(f"identifier not found: {name}")


class BreakSignal(Exception):
    pass


class ContinueSignal(Exception):
    pass


class Integer:
    def __init__(self, value: int):
        self.value = int(value)


class Float:
    def __init__(self, value: float):
        self.value = float(value)


class Boolean:
    def __init__(self, value: bool):
        self.value = bool(value)


class String:
    def __init__(self, value: str):
        self.value = str(value)


class Null:
    pass


class Array:
    def __init__(self, elements: List[Any]):
        self.elements = elements


class Error:
    def __init__(self, message: str):
        self.message = message


@dataclass
class NyxClass:
    name: str
    methods: Dict[str, "UserFunction"]

    def instantiate(self, interpreter: "Interpreter", args: List[Any]) -> Dict[str, Any]:
        instance: Dict[str, Any] = {"__class__": self}
        init_fn = self.methods.get("init")
        if init_fn is not None:
            init_fn.call(interpreter, [instance, *args])
        return instance

    def __call__(self, *args: Any) -> Dict[str, Any]:
        return {"__class__": self}


@dataclass
class UserFunction:
    parameters: List[Identifier]
    body: BlockStatement
    env: Environment

    def call(self, interpreter: "Interpreter", args: List[Any]) -> Any:
        local = Environment(self.env)
        for i, param in enumerate(self.parameters):
            local.define(param.value, args[i] if i < len(args) else NULL)
        try:
            return interpreter.eval(self.body, local)
        except ReturnSignal as ret:
            return ret.value

def _truthy(value: Any) -> bool:
    if value is NULL:
        return False
    return bool(value)


def _type_name(value: Any) -> str:
    if isinstance(value, bool):
        return "BOOLEAN"
    if isinstance(value, int):
        return "INTEGER"
    if isinstance(value, float):
        return "FLOAT"
    if isinstance(value, str):
        return "STRING"
    return type(value).__name__.upper()


class Interpreter:
    def __init__(self):
        self.builtins: Dict[str, Callable[..., Any]] = {
            "print": self._builtin_print,
            "len": self._builtin_len,
            "range": self._builtin_range,
            "max": lambda v: max(v),
            "min": lambda v: min(v),
            "sum": lambda v: sum(v),
            "abs": lambda v: abs(v),
            "round": lambda v: round(v),
            "str": lambda v: str(v),
            "int": lambda v: int(v),
            "float": lambda v: float(v),
        }
        self.strict_unknown_nodes = False
        self.modules: Dict[str, Dict[str, Any]] = {}
        self.import_resolvers: List[Callable[[str], Optional[Dict[str, Any]]]] = []
        self.max_steps = 1_000_000
        self._steps = 0

    def register_builtin(self, name: str, fn: Callable[..., Any]) -> None:
        self.builtins[name] = fn

    def register_module(self, name: str, values: Dict[str, Any]) -> None:
        self.modules[name] = dict(values)

    def register_import_resolver(self, resolver: Callable[[str], Optional[Dict[str, Any]]]) -> None:
        self.import_resolvers.append(resolver)

    def resolve_module(self, name: str) -> Optional[Dict[str, Any]]:
        if name in self.modules:
            return self.modules[name]
        for resolver in self.import_resolvers:
            resolved = resolver(name)
            if resolved is not None:
                self.modules[name] = dict(resolved)
                return self.modules[name]
        return None

    def _builtin_print(self, *values: Any) -> Any:
        print(*values)
        return NULL

    def _builtin_len(self, value: Any) -> int:
        return len(value)

    def _builtin_range(self, n: int) -> List[int]:
        return list(range(int(n)))

    def eval_node(self, node: Any, env: Optional[Environment] = None) -> Any:
        # Stable alias for external integrations.
        return self.eval(node, env)

    def eval(self, node: Any, env: Optional[Environment] = None) -> Any:
        if env is None:
            env = Environment()
            self._steps = 0
        self._steps += 1
        if self._steps > self.max_steps:
            raise RuntimeError("interpreter step limit exceeded")

        if isinstance(node, Program):
            result: Any = NULL
            for stmt in node.statements:
                result = self.eval(stmt, env)
            return result

        if isinstance(node, BlockStatement):
            result: Any = NULL
            for stmt in node.statements:
                result = self.eval(stmt, env)
            return result

        if isinstance(node, ExpressionStatement):
            return self.eval(node.expression, env)

        if isinstance(node, LetStatement):
            value = self.eval(node.value, env)
            return env.define(node.name.value, value)

        if isinstance(node, BreakStatement):
            raise BreakSignal()

        if isinstance(node, ContinueStatement):
            raise ContinueSignal()

        if isinstance(node, ImportStatement):
            if node.path is None:
                return NULL
            mod = self.resolve_module(node.path.value)
            if mod is None:
                # Soft-fail for forward compatibility.
                return NULL
            return mod

        if isinstance(node, UseStatement):
            mod = self.resolve_module(node.module)
            if mod is None:
                return NULL
            return mod

        if isinstance(node, FromStatement):
            if node.path is None:
                return NULL
            mod = self.resolve_module(node.path.value)
            if mod is None:
                return NULL
            for ident in node.imports:
                if ident.value == "*":
                    for k, v in mod.items():
                        env.define(k, v)
                elif ident.value in mod:
                    env.define(ident.value, mod[ident.value])
            return NULL

        if isinstance(node, ReturnStatement):
            value = NULL if node.return_value is None else self.eval(node.return_value, env)
            raise ReturnSignal(value)

        if isinstance(node, Identifier):
            if node.value in self.builtins:
                return self.builtins[node.value]
            return env.get(node.value)

        if isinstance(node, SelfExpression):
            return env.get("self")

        if isinstance(node, AssignExpression):
            value = self.eval(node.value, env)
            if isinstance(node.name, Identifier):
                return env.set(node.name.value, value)
            if isinstance(node.name, InfixExpression) and node.name.operator == ".":
                obj = self.eval(node.name.left, env)
                if isinstance(obj, dict) and isinstance(node.name.right, Identifier):
                    obj[node.name.right.value] = value
                    return value
            raise RuntimeError("unsupported assignment target")

        if isinstance(node, IntegerLiteral):
            return node.value
        if isinstance(node, FloatLiteral):
            return node.value
        if isinstance(node, StringLiteral):
            return node.value
        if isinstance(node, BooleanLiteral):
            return node.value
        if isinstance(node, NullLiteral):
            return NULL
        if isinstance(node, ArrayLiteral):
            return [self.eval(el, env) for el in node.elements]

        if isinstance(node, HashLiteral):
            out: Dict[Any, Any] = {}
            if isinstance(node.pairs, dict):
                iterable = node.pairs.items()
            else:
                iterable = node.pairs or []
            for k, v in iterable:
                out[self.eval(k, env)] = self.eval(v, env)
            return out

        if isinstance(node, IndexExpression):
            left = self.eval(node.left, env)
            index = self.eval(node.index, env)
            try:
                return left[index]
            except Exception:
                return NULL

        if isinstance(node, PrefixExpression):
            right = self.eval(node.right, env)
            if node.operator == "!":
                return not _truthy(right)
            if node.operator == "-":
                if isinstance(right, bool):
                    raise RuntimeError("unknown operator: -BOOLEAN")
                return -right
            if node.operator == "~":
                return ~int(right)
            return right

        if isinstance(node, InfixExpression):
            op = node.operator
            if op == ".":
                left = self.eval(node.left, env)
                if isinstance(left, dict) and isinstance(node.right, Identifier):
                    name = node.right.value
                    if name in left:
                        return left[name]
                    cls = left.get("__class__")
                    if isinstance(cls, NyxClass) and name in cls.methods:
                        fn = cls.methods[name]
                        local = UserFunction(fn.parameters, fn.body, fn.env)
                        def method(*args: Any) -> Any:
                            return local.call(self, [left, *args])
                        return method
                raise RuntimeError("member access on non-object")
            left = self.eval(node.left, env)
            right = self.eval(node.right, env)
            if op == "+":
                if isinstance(left, bool) and isinstance(right, bool):
                    raise RuntimeError("unknown operator: BOOLEAN + BOOLEAN")
                if isinstance(left, bool) or isinstance(right, bool):
                    raise RuntimeError(f"type mismatch: {_type_name(left)} + {_type_name(right)}")
                # String concatenation: convert to string if either operand is a string
                if isinstance(left, str) or isinstance(right, str):
                    return str(left) + str(right)
                return left + right
            if op == "-":
                if isinstance(left, bool) or isinstance(right, bool):
                    raise RuntimeError("unknown operator: BOOLEAN - BOOLEAN")
                return left - right
            if op == "*":
                if isinstance(left, bool) or isinstance(right, bool):
                    raise RuntimeError("unknown operator: BOOLEAN * BOOLEAN")
                return left * right
            if op == "/":
                if isinstance(left, bool) or isinstance(right, bool):
                    raise RuntimeError("unknown operator: BOOLEAN / BOOLEAN")
                return left / right
            if op == "%":
                return left % right
            if op == "**":
                return left ** right
            if op == "==":
                return left == right
            if op == "!=":
                return left != right
            if op == "<":
                return left < right
            if op == "<=":
                return left <= right
            if op == ">":
                return left > right
            if op == ">=":
                return left >= right
            if op == "&&":
                return _truthy(left) and _truthy(right)
            if op == "||":
                return _truthy(left) or _truthy(right)
            raise RuntimeError(f"unsupported operator: {op}")

        if isinstance(node, IfExpression):
            if _truthy(self.eval(node.condition, env)):
                return self.eval(node.consequence, env)
            if node.alternative is not None:
                return self.eval(node.alternative, env)
            return NULL

        if isinstance(node, WhileStatement):
            result = NULL
            while _truthy(self.eval(node.condition, env)):
                try:
                    result = self.eval(node.body, env)
                except ContinueSignal:
                    continue
                except BreakSignal:
                    break
            return result

        if isinstance(node, ForStatement):
            result = NULL
            local = Environment(env)
            if node.initialization is not None:
                self.eval(node.initialization, local)
            while True:
                if node.condition is not None and not _truthy(self.eval(node.condition, local)):
                    break
                try:
                    result = self.eval(node.body, local)
                except ContinueSignal:
                    pass
                except BreakSignal:
                    break
                if node.increment is not None:
                    self.eval(node.increment, local)
            return result

        if isinstance(node, ForInStatement):
            result = NULL
            local = Environment(env)
            iterable = self.eval(node.iterable, local)
            try:
                iterator = list(iterable)
            except Exception:
                raise RuntimeError("for-in iterable is not iterable")
            for item in iterator:
                if node.iterator is not None:
                    local.define(node.iterator.value, item)
                try:
                    result = self.eval(node.body, local)
                except ContinueSignal:
                    continue
                except BreakSignal:
                    break
            return result

        if isinstance(node, FunctionLiteral):
            return UserFunction(node.parameters, node.body, env)

        if isinstance(node, ClassStatement):
            methods: Dict[str, UserFunction] = {}
            for stmt in node.body.statements if node.body is not None else []:
                if isinstance(stmt, ExpressionStatement) and isinstance(stmt.expression, FunctionLiteral):
                    fn = stmt.expression
                    if fn.name is not None:
                        methods[fn.name.value] = UserFunction(fn.parameters, fn.body, env)
            cls = NyxClass(name=node.name.value if node.name else "Anonymous", methods=methods)
            if node.name is not None:
                env.define(node.name.value, cls)
            return cls

        if isinstance(node, NewExpression):
            # `new X(args)` is parsed as NewExpression(CallExpression(...)) in this grammar.
            if isinstance(node.cls, CallExpression) and isinstance(node.cls.function, Identifier):
                cls_name = node.cls.function.value
                cls_obj = env.get(cls_name)
                args = [self.eval(arg, env) for arg in (node.cls.arguments or [])]
                if isinstance(cls_obj, NyxClass):
                    return cls_obj.instantiate(self, args)
            cls_val = self.eval(node.cls, env)
            if isinstance(cls_val, NyxClass):
                return cls_val.instantiate(self, [])
            return cls_val

        if isinstance(node, CallExpression):
            if isinstance(node.function, NewExpression):
                class_expr = node.function.cls
                cls_val = self.eval(class_expr, env)
                args = [self.eval(arg, env) for arg in (node.arguments or [])]
                if isinstance(cls_val, NyxClass):
                    return cls_val.instantiate(self, args)
                raise RuntimeError("attempt to instantiate non-class")
            fn = self.eval(node.function, env)
            args = [self.eval(arg, env) for arg in (node.arguments or [])]
            if isinstance(fn, NyxClass):
                return fn.instantiate(self, args)
            if isinstance(fn, UserFunction):
                return fn.call(self, args)
            if callable(fn):
                return fn(*args)
            raise RuntimeError("attempt to call non-function")

        if self.strict_unknown_nodes:
            raise RuntimeError(f"unsupported AST node: {type(node).__name__}")
        return NULL


def _wrap_runtime(value: Any) -> Any:
    if value is NULL:
        return Null()
    if isinstance(value, bool):
        return Boolean(value)
    if isinstance(value, int):
        return Integer(value)
    if isinstance(value, float):
        return Float(value)
    if isinstance(value, str):
        return String(value)
    if isinstance(value, list):
        return Array([_wrap_runtime(v) for v in value])
    return value


async def evaluate(program: Any, env: Optional[Environment] = None) -> Any:
    try:
        value = Interpreter().eval(program, env or Environment())
        return _wrap_runtime(value)
    except Exception as exc:
        return Error(str(exc))
