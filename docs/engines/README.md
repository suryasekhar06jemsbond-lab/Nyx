# Nyx Engine Packages

Comprehensive external packages for the Nyx programming language, equivalent to Python's major libraries.

## Installation

```bash
nypm install Nygame
nypm install Nygui
nypm install Nyml
# etc.
```

## Available Engines

### Core & Infrastructure

| Engine | Package | Python Equivalent | Description |
|--------|---------|------------------|-------------|
| **Nygame** | Nygame | pygame, arcade, panda3d | Game development with physics, AI, characters |
| **Nygui** | Nygui | PyQt, Tkinter, Kivy | GUI framework with widgets, layouts |
| **Nyml** | Nyml | TensorFlow, PyTorch, scikit-learn | Machine learning & neural networks |
| **Nycrypto** | Nycrypto | cryptography, PyCryptodome | Cryptography & hashing |
| **Nydatabase** | Nydatabase | SQLAlchemy, psycopg2 | Database operations & SQL |
| **Nynetwork** | Nynetwork | aiohttp, requests | HTTP, WebSocket, sockets |
| **Nyls** | Nyls | pylsp, pyright | Language Server Protocol for IDE integration |
| **Nyserver** | Nyserver | gunicorn, uwsgi | Server infrastructure and process management |
| **NyBuild** | NyBuild | cargo, bazel | Build system with DAG, caching, testing |
| **Nypm** | Nypm | pip, cargo | Package manager with semver, security |
| **NyQueue** | NyQueue | rabbitmq, kafka, celery | Message queue, job processing, event streaming |

### Scientific Computing

| Engine | Package | Python Equivalent | Description |
|--------|---------|------------------|-------------|
| **Nyarray** | Nyarray | NumPy + SciPy + SymPy | Arrays, linear algebra, signal processing, optimization, statistics, symbolic math |

### Web & API

| Engine | Package | Python Equivalent | Description |
|--------|---------|------------------|-------------|
| **Nyweb** | Nyweb | Django + Flask + FastAPI | Full-stack web framework with ORM, templates, REST API |
| **Nyhttp** | Nyhttp | httpx + aiohttp | Modern HTTP client & server with HTTP/2, HTTP/3 support |

### Automation & Scraping

| Engine | Package | Python Equivalent | Description |
|--------|---------|------------------|-------------|
| **Nyautomate** | Nyautomate | requests + selenium + scrapy | HTTP client, web scraping, browser automation, SSH |

### Media Processing

| Engine | Package | Python Equivalent | Description |
|--------|---------|------------------|-------------|
| **Nymedia** | Nymedia | Pillow + OpenCV + moviepy | Image, video, audio processing |

### Security

| Engine | Package | Python Equivalent | Description |
|--------|---------|------------------|-------------|
| **Nysec** | Nysec | scapy + pwntools | Packet crafting, exploit development, advanced crypto |

## Usage Examples

### Game Development (Nygame)
```nyx
use Nygame;

let game = Nygame.Game.new("My Game", 800, 600);
game.run();
```

### GUI Application (Nygui)
```nyx
use Nygui;

let window = Nygui.Window.new("App", 400, 300);
let button = Nygui.Button.new("Click Me");
window.add(button);
window.show();
```

### Machine Learning (Nyml)
```nyx
use Nyml;

let model = Nyml.Sequential.from_layers([
    Nyml.Dense.new(784, 128, activation="relu"),
    Nyml.Dense.new(128, 10, activation="softmax"),
]);
model.fit(train_data, epochs=10);
```

### HTTP Requests (Nyautomate)
```nyx
use Nyautomate;

let response = Nyautomate.get("https://api.example.com");
io.println(response.json());
```

### Image Processing (Nymedia)
```nyx
use Nymedia;

let img = Nymedia.Image.open("photo.jpg");
let resized = img.resize(256, 256);
resized.save("photo_small.jpg");
```

### Web Framework (Nyweb)
```nyx
use Nyweb;

let app = Nyweb.Application.new("MyApp");

@app.get("/")
fn home(req: Nyweb.Request) -> Nyweb.Response {
    return Nyweb.Response.html("<h1>Hello Nyx!</h1>");
}

app.run("localhost", 8080);
```

### Packet Crafting (Nysec)
```nyx
use Nysec;

let packet = Nysec.IP(dst="192.168.1.1") / Nysec.ICMP();
Nysec.send(packet);
```

### Database Operations (Nydatabase)
```nyx
use Nydatabase;

# Create database with connection pooling
let db = Nydatabase.Database.sqlite();
db.connect();

# Define table schema
let users = Nydatabase.Table.new("users");
users.id();
users.column("name", "TEXT").not_null();
users.column("email", "TEXT").unique();
users.timestamps();
db.create_table(users);

# Insert using query builder
db.insert("users").values({"name": "Alice", "email": "alice@example.com"}).execute(db.connection());

# Query using chainable builder
let result = Nydatabase.QueryBuilder.table("users")
    .where_eq("name", "Alice")
    .first(db.connection());

# Use ORM
let user = Nydatabase.Model.table("users");
user.create({"name": "Bob", "email": "bob@example.com"});
```

### Package Management (Nypm)
```bash
# Initialize new package
nypm init myapp

# Add dependencies
nypm add nyweb ^3.0
nypm add nydatabase --dev

# Install all dependencies
nypm install

# Update packages
nypm update
nypm outdated

# Run scripts
nypm run start
nypm run test

# Package management
nypm list
nypm search web
nypm publish

# Security audit
nypm audit

# Workspace support
nypm workspace init
nypm workspace add packages/api
```

### Build System (NyBuild)
```bash
# Initialize project
ny init myapp

# Build project
ny build
ny build --profile release
ny build --parallel 8

# Build and run
ny run myapp

# Run tests
ny test
ny test --coverage

# Code quality
ny check          # Lint + format check
ny fmt            # Format code
ny lint           # Lint only

# Release
ny release 1.0.0
ny release 1.0.0 --channel beta

# Watch mode
ny build --watch

# CI mode
ny ci

# Clean
ny clean
```

### Message Queue (NyQueue)
```nyx
use NyQueue;

# Create queue
let queue = NyQueue.MessageQueue.new();
queue.declare(NyQueue.Queue.new("emails"));

# Publish job
let msg = NyQueue.Message.new("emails", {
    to: "user@example.com",
    subject: "Hello",
    body: "Welcome!"
});
queue.publish(msg);

# Create worker
let worker = NyQueue.Worker.new("email-worker")
    .subscribe("emails")
    .concurrency(4)
    .timeout(30000);

# Process jobs
for message in worker.consume() {
    # Send email
    send_email(message.payload);
    worker.ack(message.id);
}

# Delayed jobs
let delayed = NyQueue.Message.new("reports", data)
    .delay(3600000);  # 1 hour delay
queue.publish(delayed);

# Scheduled jobs
let job = NyQueue.Job.new("backup", {})
    .cron("0 2 * * *")  # Daily at 2am
    .schedule();
```

### Language Server (Nyls)
```nyx
use Nyls;

let server = Nyls.LanguageServer.new();
server.initialize("./project");
server.start();
```

### HTTP Client (Nyhttp)
```nyx
use Nyhttp;

let client = Nyhttp.HttpClient.new();
let response = client.get("https://api.example.com/data");
io.println(response.json());
```

### Server Infrastructure (Nyserver)
```nyx
use Nyserver;

let server = Nyserver.Server.new("myapp", "localhost", 8080);
server.with_workers(4);
server.start();

# Or use process management
let manager = Nyserver.ProcessManager.new();
manager.spawn("worker", "myapp", ["--workers", "4"]);
```

## Development

To build your own engine:

1. Create a directory in `engines/`
2. Add your `ny.pkg` configuration
3. Add your main `*.ny` files
4. Test with `nypm install ./engines/<EngineName>`

## License

MIT License - See individual package licenses for details.
