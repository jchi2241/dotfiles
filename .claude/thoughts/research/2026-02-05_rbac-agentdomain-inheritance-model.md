---
type: research
title: RBAC Model and AgentDomain Permission Inheritance
project: helios
area: singlestore.com/helios/authz
tags: [rbac, agentdomain, permissions, authorization, inheritance]
date: 2026-02-05
status: complete
related_plans: []
---

# RBAC Model and AgentDomain Permission Inheritance

## Overview

The Helios RBAC (Role-Based Access Control) system implements a hierarchical permission model where Organization-level roles can inherit permissions from resource-specific roles. This research specifically examines how Organization Owners inherit AgentDomain permissions.

## Key Components

### Authorization Model Files
- **YAML Configuration Files**: `singlestore.com/helios/authz/model/yaml/`
  - `organization.yaml` - Defines Organization roles and their inheritance
  - `agentdomain.yaml` - Defines AgentDomain roles and permissions

### Core Authorization Implementation
- **Main Engine**: `singlestore.com/helios/authz/impl/authorization.go`
- **Model Loader**: `singlestore.com/helios/authz/model/model.go`
- **Type Definitions**: `singlestore.com/helios/authz/authorization.go`
- **GraphQL Mapping**: `singlestore.com/helios/graph/authz.go:385-415`

## Data Flow

### 1. Model Loading Process
The authorization model is loaded at initialization:
- YAML files are embedded using `//go:embed` directive (`model/model.go:36`)
- `New()` function unmarshals YAML files into ResourceTypeModel structures (`model/model.go:40-66`)
- Each resource type (Organization, AgentDomain, etc.) has its own model

### 2. Role Inheritance Resolution
When checking permissions:
1. System retrieves grants for a user/team on a resource
2. `forEachGrantedRole()` function processes each granted role (`impl/authorization.go:300-331`)
3. For each role, it recursively processes inherited roles (`impl/authorization.go:378-389`)
4. Permissions from all roles and inherited roles are aggregated

## API Contracts

### AgentDomain Permissions
Defined in `agentdomain.yaml`:
- **Update** - Update current domain
- **Delete** - Delete current domain
- **Control Access** - Invite/Remove users from current domain
- **Use** - Use current domain
- **View Agent Domain Feedback** - View feedback submitted by domain users
- **View Agent Domain User Conversations** - View other users' conversation threads

### AgentDomain Roles
- **Owner**: Has all 6 permissions listed above
- **User**: Has only "Use" permission

## Dependencies

### Resource Hierarchy
- AgentDomain requires Organization as parent (`agentdomain.yaml:2-3`)
- Organization contains multiple resource types including AgentDomains

### Permission Checking Flow
1. User makes request → `graph/server/public/agentdomains.go`
2. Calls `GrantedPermissions()` → `authz/impl/authorization.go:286`
3. Retrieves grants from database
4. Processes role inheritance
5. Returns aggregated permission set

## Configuration

### Organization Owner Role Inheritance
From `organization.yaml:3-13`:
```yaml
- name: Owner
  desc: Organization owner
  inherits:
  - name: Owner
    resourceType: Cluster
  - name: Owner
    resourceType: Team
  - name: Owner
    resourceType: AuraApp
  - name: Owner
    resourceType: AgentDomain
```

**CRITICAL FINDING**: Organization Owners explicitly inherit the AgentDomain Owner role, which grants them all AgentDomain permissions including Update, Delete, Control Access, Use, View Feedback, and View User Conversations.

## Code References

### Key Functions for Permission Checking
- Permission resolution: `singlestore.com/helios/authz/impl/authorization.go:394` (`getGrantedPermissions()`)
- Role inheritance processing: `singlestore.com/helios/authz/impl/authorization.go:368` (`processGrantedRole()`)
- Recursive inheritance: `singlestore.com/helios/authz/impl/authorization.go:378-389`

### AgentDomain Access Control
- GraphQL resolver: `singlestore.com/helios/graph/server/public/agentdomains.go:30-43`
- Permission mapping: `singlestore.com/helios/graph/authz.go:385-415`
- Access check: `singlestore.com/helios/novaapps/CheckAgentDomainAccess()` (referenced at `agentdomains.go:75`)

### Data Structures
- Role definition with inheritance: `singlestore.com/helios/authz/authorization.go:105-115`
- Resource types enum: `singlestore.com/helios/authz/uuid.go:41-50`

## Answer to Research Question

**Organization owners DO inherit AgentDomain Owner permissions.**

The inheritance is explicitly defined in the YAML configuration (`organization.yaml:12-13`) and implemented through the recursive role processing mechanism in the authorization engine. When an Organization Owner's permissions are evaluated for an AgentDomain resource:

1. The system identifies the user has Organization Owner role
2. It processes the Organization Owner role definition
3. It finds the inherited AgentDomain Owner role in the inheritance list
4. It recursively grants all permissions from the AgentDomain Owner role
5. The user receives all 6 AgentDomain permissions: Update, Delete, Control Access, Use, View Agent Domain Feedback, and View Agent Domain User Conversations

This inheritance is automatic and cannot be overridden at the individual AgentDomain level - it's a system-wide authorization model configuration.