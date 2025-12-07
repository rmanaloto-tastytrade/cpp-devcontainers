# AI Agent SDK Research  

## Overview  

This document summarizes research on various open-source or free AI agent frameworks, SDKs, and runtimes that enable agent orchestration, tool integration, memory, planning, and DevOps automation. It considers features, difficulty of integration, and typical use cases.  

## Comparison Table  

| Framework | Category | License | Difficulty | Features | DevOps/CI/CD | Notes |  
|---|---|---|---|---|---|---|  
| **Docker Cagent** | DevOps agent runtime | Apache‑2.0 | Easy | Docker automation, tool calls | Excellent (native Docker integration) | Ideal for container build tasks and CI/CD troubleshooting |  
| **Microsoft AutoGen** | Multi‑agent orchestration | MIT | Medium | Multi‑agent, tool calling, memory | Possible | Powerful multi‑agent system; supports many LLMs |  
| **LangChain Agents** | General agent tooling | Apache‑2.0 | Medium | Tool calling, memory, RAG | Supported | Large ecosystem, good starting point |  
| **LangGraph** | Reliable state machines | Apache‑2.0 | Hard | Deterministic workflows, resumable graphs | Medium | Best for safe, resumable agent pipelines |  
| **CrewAI** | Agent teams | OSS | Easy | Multi‑agent collaboration, tool use | Some | Defines “crew” roles and goals |  
| **LlamaIndex Agents** | RAG‑first agents | OSS | Medium | Document retrieval, tool calls | Some | Great for data + retrieval‑augmented tasks |  
| **FastAgency** | Reliable tool execution | OSS | Easy | Browser/API automation, guardrails | Strong | Focus on safe function execution |  
| **SmolAgents** | Lightweight local agents | OSS | Easy | Tool calling | Some | Runs with local models via Ollama |  
| **SuperAgent** | Self‑hosted agent server | OSS | Medium | Tool calling, memory | Medium | Provides REST API for agent orchestration |  
| **OpenAGI** | Full orchestration engine | OSS | Hard | Task decomposition, memory | Medium | Research‑grade autonomous agents |  
| **Griptape** | Workflow agents | OSS | Medium | Tools, memory, workflows | Some | Enterprise‑oriented workflow definitions |  
| **TaskWeaver** | Code‑execution agents | OSS | Medium | Python code generation/execution | Some | Good for automating code-based tasks |  
| **DSPy** | Programmatic LLM logic | OSS | Hard | Structured prompting, evaluation | Limited | Designed for deterministic reasoning |  
| **FlowiseAI** | Visual builder | OSS | Easy | Tool calls, memory | Some | Visual drag‑and‑drop agent flows |  
| **OpenHands** | Computer control agents | OSS | Medium | OS/browser automation | Medium | Agents can operate computer tasks |  

## Notes  

- **Docker Cagent** is unique in providing an AI‑powered agent within Docker tooling. It automates Dockerfile updates, builds, compose operations, and integrates with GitHub Actions for CI/CD pipelines.  
- **AutoGen**, **CrewAI**, and **LangGraph** are strong choices for multi‑agent orchestration where agents collaborate, delegate tasks, and maintain memory.  
- **LangChain Agents** and **LlamaIndex Agents** benefit from large ecosystems of tools and vector stores, making them versatile for RAG and general tool‑calling scenarios.  
- **FastAgency** and **SmolAgents** offer easy integration for safe, deterministic agents, especially when running local models.  
- **FlowiseAI** provides a visual interface for building and exporting agent flows as APIs, which can be convenient for rapid prototyping. 
