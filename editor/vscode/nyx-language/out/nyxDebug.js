"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NyxDebugSession = void 0;
const debugadapter_1 = require("@vscode/debugadapter");
const path_1 = require("path");
const fs = require("fs");
const net = require("net");
const child_process_1 = require("child_process");
class NyxDebugSession extends debugadapter_1.LoggingDebugSession {
    constructor() {
        super("nyx-debug.txt");
        // Maps to track requests and variables
        this._variableHandles = new debugadapter_1.Handles();
        this._buffer = "";
        this.idGenerator = 1000;
        // this debugger uses zero-based lines and columns
        this.setDebuggerLinesStartAt1(false);
        this.setDebuggerColumnsStartAt1(false);
    }
    /**
     * The 'initialize' request is the first request called by the frontend
     * to interrogate the features the debug adapter provides.
     */
    initializeRequest(response, args) {
        // build and return the capabilities of this debug adapter:
        response.body = response.body || {};
        // the adapter implements the configurationDoneRequest.
        response.body.supportsConfigurationDoneRequest = true;
        // make VS Code use 'evaluate' when hovering over source
        response.body.supportsEvaluateForHovers = true;
        // make VS Code support data breakpoints
        response.body.supportsDataBreakpoints = false;
        // make VS Code send cancelRequests
        response.body.supportsCancelRequest = true;
        // make VS Code send the breakpointLocations request
        response.body.supportsBreakpointLocationsRequest = true;
        this.sendResponse(response);
        // since this debug adapter can accept configuration requests like 'setBreakpoint' at any time,
        // we request them early by sending an 'initialized' event to the frontend.
        this.sendEvent(new debugadapter_1.InitializedEvent());
    }
    /**
     * Called at the end of the configuration sequence.
     * Indicates that all breakpoints etc. have been sent to the DA and that the 'launch' can start.
     */
    configurationDoneRequest(response, args) {
        super.configurationDoneRequest(response, args);
        // notify the launchRequest that configuration has finished
        // this.configurationDone.notify();
    }
    async launchRequest(response, args) {
        // make sure to 'Stop' the buffered logging if 'trace' is not set
        debugadapter_1.logger.setup(args.trace ? debugadapter_1.Logger.LogLevel.Verbose : debugadapter_1.Logger.LogLevel.Stop, false);
        // Verify file exists
        if (!fs.existsSync(args.program)) {
            this.sendErrorResponse(response, 2001, `Cannot find program '${args.program}'`);
            return;
        }
        const port = args.port || 9229;
        // Start the actual runtime
        this._serverProcess = (0, child_process_1.spawn)('nyx', [`--debug-port=${port}`, args.program]);
        this._serverProcess.stdout?.on('data', (data) => {
            this.sendEvent(new debugadapter_1.OutputEvent(data.toString(), 'stdout'));
        });
        this._serverProcess.stderr?.on('data', (data) => {
            this.sendEvent(new debugadapter_1.OutputEvent(data.toString(), 'stderr'));
        });
        this._serverProcess.on('exit', () => {
            this.sendEvent(new debugadapter_1.TerminatedEvent());
        });
        await this.connect(port);
        this.sendResponse(response);
        // We stop on entry if requested
        if (args.stopOnEntry) {
            this.sendEvent(new debugadapter_1.StoppedEvent('entry', NyxDebugSession.THREAD_ID));
        }
        else {
            // Otherwise we would continue
            // this.continueRequest(...)
        }
    }
    async attachRequest(response, args) {
        const port = args.port || 9229;
        await this.connect(port);
        this.sendResponse(response);
    }
    disconnectRequest(response, args, request) {
        if (this._serverProcess) {
            this._serverProcess.kill();
        }
        if (this._clientSocket) {
            this._clientSocket.destroy();
        }
        super.disconnectRequest(response, args, request);
    }
    connect(port) {
        return new Promise((resolve, reject) => {
            let retries = 5;
            const attempt = () => {
                const socket = net.createConnection(port, '127.0.0.1');
                socket.on('connect', () => {
                    this._clientSocket = socket;
                    this._clientSocket.on('data', (data) => this.handleData(data));
                    this._clientSocket.on('error', (err) => this.sendEvent(new debugadapter_1.OutputEvent(`Socket error: ${err.message}\n`, 'stderr')));
                    this._clientSocket.on('close', () => this.sendEvent(new debugadapter_1.TerminatedEvent()));
                    resolve();
                });
                socket.on('error', (err) => {
                    if (retries-- > 0)
                        setTimeout(attempt, 200);
                    else
                        reject(err);
                });
            };
            attempt();
        });
    }
    handleData(data) {
        this._buffer += data.toString();
        // Simple line-based JSON protocol handler
        const lines = this._buffer.split('\n');
        this._buffer = lines.pop() || ""; // Keep incomplete line
        for (const line of lines) {
            if (line.trim().length === 0)
                continue;
            try {
                const msg = JSON.parse(line);
                this.handleRuntimeMessage(msg);
            }
            catch (e) {
                this.sendEvent(new debugadapter_1.OutputEvent(`Invalid protocol message: ${line}\n`, 'stderr'));
            }
        }
    }
    handleRuntimeMessage(msg) {
        if (msg.type === 'event') {
            if (msg.event === 'stopped') {
                this.sendEvent(new debugadapter_1.StoppedEvent(msg.body.reason, NyxDebugSession.THREAD_ID));
            }
            else if (msg.event === 'output') {
                this.sendEvent(new debugadapter_1.OutputEvent(msg.body.output, msg.body.category || 'console'));
            }
        }
        // In a real implementation, we would map responses to request IDs here
    }
    sendToRuntime(command, args) {
        if (this._clientSocket) {
            const msg = JSON.stringify({ command, arguments: args });
            this._clientSocket.write(msg + '\n');
        }
    }
    setBreakpointsRequest(response, args) {
        const path = args.source.path;
        const clientLines = args.lines || [];
        // Send breakpoints to the runtime
        this.sendToRuntime('setBreakpoints', {
            path,
            lines: clientLines
        });
        // Return verified breakpoints to VS Code
        const actualBreakpoints = clientLines.map(l => {
            const bp = new debugadapter_1.Breakpoint(true, l);
            bp.id = this.idGenerator++;
            return bp;
        });
        response.body = {
            breakpoints: actualBreakpoints
        };
        this.sendResponse(response);
    }
    threadsRequest(response) {
        // runtime supports no threads so just return a default thread.
        response.body = {
            threads: [
                new debugadapter_1.Thread(NyxDebugSession.THREAD_ID, "thread 1")
            ]
        };
        this.sendResponse(response);
    }
    stackTraceRequest(response, args) {
        const startFrame = args.startFrame || 0;
        const levels = args.levels || 10;
        // For now, return a dummy stack frame to allow the UI to show something
        // In a real scenario, we would await a response from sendToRuntime('stackTrace')
        const stk = new debugadapter_1.StackFrame(0, "main", new debugadapter_1.Source((0, path_1.basename)("main.nx"), "main.nx"), 1, 1);
        response.body = {
            stackFrames: [stk],
            totalFrames: 1
        };
        this.sendResponse(response);
    }
    scopesRequest(response, args) {
        const frameId = args.frameId;
        const scopes = [
            new debugadapter_1.Scope("Local", this._variableHandles.create("local_" + frameId), false),
            new debugadapter_1.Scope("Global", this._variableHandles.create("global_" + frameId), true)
        ];
        response.body = {
            scopes: scopes
        };
        this.sendResponse(response);
    }
    variablesRequest(response, args) {
        const variables = [];
        const id = this._variableHandles.get(args.variablesReference);
        if (id) {
            // Mock variables for demonstration
            variables.push({
                name: "demo_var",
                value: "\"Hello Nyx\"",
                variablesReference: 0
            });
        }
        response.body = {
            variables: variables
        };
        this.sendResponse(response);
    }
    continueRequest(response, args) {
        this.sendToRuntime('continue', {});
        this.sendResponse(response);
    }
    nextRequest(response, args) {
        this.sendToRuntime('next', {});
        this.sendResponse(response);
    }
    stepInRequest(response, args) {
        this.sendToRuntime('stepIn', {});
        this.sendResponse(response);
    }
    stepOutRequest(response, args) {
        this.sendToRuntime('stepOut', {});
        this.sendResponse(response);
    }
    evaluateRequest(response, args) {
        this.sendToRuntime('evaluate', { expression: args.expression });
        response.body = {
            result: `result of ${args.expression}`,
            variablesReference: 0
        };
        this.sendResponse(response);
    }
}
exports.NyxDebugSession = NyxDebugSession;
// We only support one thread for now
NyxDebugSession.THREAD_ID = 1;
//# sourceMappingURL=nyxDebug.js.map