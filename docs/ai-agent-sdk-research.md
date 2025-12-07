# AI Agent SDK Research  

## Overview  
This document summarizes open source and free AI agent SDKs and frameworks that support agent orchestration, tool calling, memory, planning, and multi-model integrations. The research focuses on systems that are easy to integrate into existing projects and provides a summary table for side-by-side comparison.  

## Key Frameworks and Runtimes  

### Docker Cagent  
Docker Cagent is a DevOps-focused AI agent runtime built into Docker Desktop and CLI. It automates container workflows, builds, and deployment tasks with AI assistance.  

### AutoGen  
AutoGen by Microsoft is a multi-agent orchestration framework in Python that enables agents to collaborate, call tools, and maintain memory.  

### LangChain Agents  
LangChain offers tools, memory, and agent modules for building LLM-driven workflows. It supports many LLM providers.  

### LangGraph  
LangGraph provides deterministic, resumable workflows for agents using state machine models.  

### CrewAI  
CrewAI manages teams of role-based agents that collaborate on tasks and supports multiple LLM backends.  

### LlamaIndex Agents  
LlamaIndex is built for RAG-centric agents and integrates with local and hosted models.  

### FastAgency  
FastAgency offers reliable tool execution and browser/API automation with simple integration.  

### SmolAgents  
SmolAgents is a lightweight runtime for local models such as Llama and Mistral.  

### SuperAgent  
SuperAgent is a self-hosted agent server that provides REST API integration for tool calling, memory, and data sources.  

### OpenAGI, Griptape, TaskWeaver, DSPy, Flowise, OpenHands  
These frameworks cater to specialized needs such as orchestration engines, workflow agents, code execution, programmatic LLM logic, visual builders, and computer control.  

## Comparison Table  

| Framework | Category | License | Integration ease | Multi-agent | Tools | Memory | DevOps/CICD | Local LLM |  
|---|---|---|---|---|---|---|---|---|  
| **Docker Cagent** | DevOps agent runtime | Apache-2.0 | Easy | Limited | Yes | Basic | Excellent | Limited |  
| **AutoGen** | Multi-agent orchestration | MIT | Medium | Yes | Yes | Yes | Possible | Yes |  
| **LangChain Agents** | General tooling | Apache-2.0 | Medium | Limited | Yes | Yes | Some | Yes |  
| **LangGraph** | State machine workflows | Apache-2.0 | Hard | Yes | Yes | Strong | Medium | Yes |  
| **CrewAI** | Agent teams | OSS | Easy | Yes | Yes | Medium | Some | Yes |  
| **LlamaIndex Agents** | RAG-centric | OSS | Medium | Some | Yes | Yes | Some | Yes |  
| **FastAgency** | Tool execution engine | OSS | Easy | Some | Yes | Minimal | Strong | Yes |  
| **SmolAgents** | Lightweight runtime | OSS | Easy | Limited | Yes | Minimal | Some | Yes |  
| **SuperAgent** | Self-hosted server | OSS | Medium | Yes | Yes | Yes | Medium | Yes |  
| **OpenAGI** | Orchestration engine | OSS | Hard | Yes | Yes | Strong | Medium | Yes |  
| **Griptape** | Workflow agents | OSS | Medium | Yes | Yes | Yes | Some | Yes |  
| **TaskWeaver** | Code-gen execution | OSS | Medium | Limited | Yes | Basic | Some | Yes |  
| **DSPy** | Programmatic logic | OSS | Hard | Some | Some | Yes | Limited | Yes |  
| **FlowiseAI** | Visual builder | OSS | Easy | Limited | Yes | Yes | Some | Yes |  
| **OpenHands** | Computer control agents | OSS | Medium | Some | Yes | Minimal | Medium | Yes |  

## Notes  
- Choose **Docker Cagent** for Docker-native automation and CI/CD integration.  
- **AutoGen**, **CrewAI**, and **LangGraph** are suitable for complex multi-agent orchestration.  
- **FastAgency**, **SmolAgents**, and **FlowiseAI** offer easy drop-in integration.  
- **OpenAGI** and **DSPy** require more advanced workflow design.
