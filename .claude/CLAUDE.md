# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spring AI Alibaba is a production-ready framework for building Agentic, Workflow, and Multi-agent applications. It is an implementation of the Spring AI framework tailored for Alibaba Cloud services and components.

## Repository Structure

```
spring-ai-alibaba/
├── spring-ai-alibaba-agent-framework/   # High-level multi-agent orchestration
│   └── src/main/java/com/alibaba/cloud/ai/graph/agent/
│       ├── ReactAgent.java              # Single agent with reasoning-acting loop
│       ├── flow/agent/
│       │   ├── SequentialAgent.java     # Execute agents in sequence
│       │   ├── ParallelAgent.java       # Concurrent execution with fan-out/gather
│       │   ├── LoopAgent.java           # Iterative execution until condition met
│       │   ├── SupervisorAgent.java     # Coordinates multiple sub-agents
│       │   └── LlmRoutingAgent.java     # Conditional routing via LLM
│       ├── a2a/                          # Agent-to-Agent communication (Nacos)
│       ├── hook/                         # Hooks (MessagesAgentHook, ShellToolAgentHook)
│       └── factory/                      # AgentBuilderFactory
├── spring-ai-alibaba-graph-core/        # Low-level workflow engine
│   └── src/main/java/com/alibaba/cloud/ai/graph/
│       ├── StateGraph.java               # Main workflow definition class
│       ├── CompiledGraph.java            # Executable form of workflows
│       ├── OverAllState.java             # Central state management
│       ├── action/                       # NodeAction, AsyncNodeAction, Command
│       ├── checkpoint/                   # Persistence (Memory, SQL, Redis, Mongo, File)
│       ├── state/                        # State serialization and strategies
│       └── internal/                     # Edge, Node, GraphRunner
├── spring-ai-alibaba-studio/           # Embedded UI for visual debugging
├── spring-ai-alibaba-bom/              # Bill of Materials
├── spring-boot-starters/
│   ├── spring-ai-alibaba-starter-a2a-nacos/        # A2A via Nacos
│   ├── spring-ai-alibaba-starter-builtin-nodes/    # Built-in node implementations
│   ├── spring-ai-alibaba-starter-config-nacos/     # Dynamic config via Nacos
│   └── spring-ai-alibaba-starter-graph-observation/# Graph observability
├── examples/                           # Example applications (chatbot, deepresearch)
└── tools/make/                         # Build and linting tools (Makefile includes)
```

## Build System

### Prerequisites

- **JDK**: 17 (Required)
- **Maven**: 3.6+ (Maven Wrapper included: `./mvnw`)
- **Git**

### Common Commands

```shell
# Build the entire project (skip tests) - IMPORTANT: Auto-formats code
./mvnw -B package -DskipTests=true

# Build a specific module
./mvnw -pl :spring-ai-alibaba-agent-framework -B package -DskipTests=true

# Clean project
./mvnw clean

# Run all tests
./mvnw test

# Run a specific test class
./mvnw -pl :<module-name> -Dtest=<TestClassName> test

# Format code (Spring AI format)
mvn spring-javaformat:apply

# Remove unused imports
mvn spotless:apply

# Check code style
mvn checkstyle:check

# Make commands via Makefile (uses ./mvnw internally)
make build          # Build the project
make test           # Run tests
make lint           # Check files (yaml-lint, codespell, newline-check)
make format-check   # Format check
make format-fix     # Format fix
make spotless-apply # Remove unused imports
make checkstyle-check # Checkstyle check

# Show available Makefile targets
make help
```

### Code Quality Tools

The project uses `make` with includes from `tools/make/`:
- `make lint`: Check files (yaml-lint, codespell, newline-check)
- `make codespell`: Spell checking
- `make yaml-lint`: YAML formatting validation
- `make yaml-lint-fix`: Fix YAML formatting
- `make licenses-check`: Verify Apache 2.0 license headers
- `make licenses-fix`: Fix license headers
- `make newline-check`: Check newline consistency

## Architecture

### Layered Architecture

```
Agent Framework (high-level patterns)
    ↓ uses
Graph Core (runtime engine)
    ↓ provides
Studio/Admin (visual tools)
    ↓ integrate with
Starters (Nacos, Observation, etc.)
```

### Core Concepts

**Agent Framework** (High-level - `spring-ai-alibaba-agent-framework`):
- Uses `com.alibaba.cloud.ai.graph.agent` package
- `ReactAgent`: Single agent with reasoning-acting loop pattern
- `SequentialAgent`: Executes agents in sequence
- `ParallelAgent`: Concurrent execution with fan-out/gather pattern
- `LoopAgent`: Iterative execution until condition met
- `SupervisorAgent`: Coordinates multiple sub-agents
- `LlmRoutingAgent`: Conditional routing to different agents via LLM
- Built-in hooks: `MessagesAgentHook`, `ShellToolAgentHook`, `SkillsAgentHook`
- A2A (Agent-to-Agent) communication via Nacos service discovery

**Graph Core** (Low-level engine - `spring-ai-alibaba-graph-core`):
- Uses `com.alibaba.cloud.ai.graph` package
- `StateGraph`: Main workflow definition class
- `CompiledGraph`: Executable form of workflows (via `StateGraph.compile()`)
- `OverAllState`: Central state management with serialization and update strategies
- `NodeAction` / `AsyncNodeAction`: Functional interfaces for node logic
- `CompiledGraph`: Runtime execution with streaming support via Reactor
- Checkpoint Saver backends: `MemorySaver`, `PostgresSaver`, `MysqlSaver`, `OracleSaver`, `RedisSaver`, `MongoSaver`, `FileSystemSaver`

**StateGraph Constants** (Use these in graph definitions):
- `StateGraph.START`: Graph entry point (`__START__`)
- `StateGraph.END`: Graph terminal (`__END__`)
- `StateGraph.ERROR`: Error handler (`__ERROR__`)
- `StateGraph.NODE_BEFORE`: Hook before node execution (`__NODE_BEFORE__`)
- `StateGraph.NODE_AFTER`: Hook after node execution (`__NODE_AFTER__`)

**State Management**:
- `OverAllState`: Immutable state container with KeyStrategy per key
- KeyStrategies: `KeyStrategy.REPLACE`, `KeyStrategy.APPEND`, `KeyStrategy.MERGE`
- Registered via `OverAllState.registerKeyAndStrategy(key, strategy)`
- State serialization via `StateSerializer` implementations

**Key Architectural Patterns**:
- Human-in-the-Loop with hooks and interruption mechanisms
- Context Engineering (compaction, editing, model/tool call limits via hooks)
- A2A (Agent-to-Agent) communication via Nacos service discovery
- Nested graphs for hierarchical workflow composition (`SubGraphNode`)

## Code Style

### Java Guidelines

- **JDK 17**: Use appropriate language features (records, switch expressions, text blocks)
- **Spring Boot 3.x**: Use `jakarta.*` namespace, not `javax.*`
- **Lombok**: `@Data`, `@Slf4j`, `@Builder` are commonly used
- **Logging**: Use SLF4J (`private static final Logger log = LoggerFactory.getLogger(ClassName.class)`), avoid `System.out.println`
- **Final**: Use `final` for local variables and parameters where appropriate

### License Header

All Java files must have this license header:

```java
/*
 * Copyright 2024-2026 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
```

### Formatting

- Spring AI standard formatting applied automatically during `mvn clean package`
- Use `mvn spring-javaformat:apply` for Spring AI formatting
- Use `mvn spotless:apply` to remove unused imports
- Check style with `mvn checkstyle:check`

## Quick Reference

- **Main framework module**: `spring-ai-alibaba-agent-framework` for agent patterns
- **Runtime engine**: `spring-ai-alibaba-graph-core` for StateGraph API
- **Version**: Defined by `revision` property in pom.xml (currently `1.1.3.0-SNAPSHOT`)
- **KeyState constants**: `StateGraph.START`, `StateGraph.END`, `StateGraph.ERROR`
- **StateGraph types**: REPLACE, APPEND, MERGE strategies
- **A2A support**: Nacos 3.x integration via `spring-ai-alibaba-starter-a2a-nacos`
- **Documentation**: https://java2ai.com
- **Examples**: See `examples/` directory for chatbot and deepresearch examples

## Links

- Issues: https://github.com/alibaba/spring-ai-alibaba/issues
- Docs: https://java2ai.com
- Contributing: CONTRIBUTING.md
