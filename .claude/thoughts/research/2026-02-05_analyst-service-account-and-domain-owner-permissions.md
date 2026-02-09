---
type: research
title: Analyst Service Account and Domain Owner Permissions Research
project: helios
area: nexusapps/authz
tags: [analyst, serviceaccount, permissions, rbac, agentdomain, auraapp, nexusapp]
date: 2026-02-05
status: complete
related_plans: []
---

# Analyst Service Account and Domain Owner Permissions Research

## Overview

The Analyst (SQLBot) Nexus app uses a service account for execution and has a complex permission model that intertwines with agent domains and domain owners. This research documents the service account's role, purpose, and permissions, as well as the relationship between domain owners and Nexus app permissions.

## Key Components

### Service Account Creation and Configuration
- **File**: `singlestore-nexus/ai-apps/bot/analyst/install/install.yaml:16-20`
  - Service account resource named "SQLBotServiceAccount"
  - Configured as "analyst-serviceaccount"

- **File**: `helios/singlestore.com/helios/nexusapps/resources/create_resource.go:1707-1767`
  - Service account creation logic
  - Grants permissions to the service account

### Permission Models
- **Agent Domain Permissions**: `helios/singlestore.com/helios/authz/model/yaml/agentdomain.yaml:1-30`
  - Defines Owner and User roles for agent domains

- **Aura App Permissions**: `helios/singlestore.com/helios/authz/model/yaml/auraapp.yaml:1-32`
  - Defines Owner and User roles for Aura apps (Nexus apps)

## Service Account Role and Purpose

### Purpose
The service account serves as the execution identity for the Analyst Nexus app, allowing it to:
1. Run scheduled jobs and notebooks
2. Access agent domains
3. Execute queries against workspace databases
4. Interact with inference APIs

### Creation Process
When the Analyst app is installed:
1. A service account is created with a unique name (`analyst-serviceaccount-{clusterID[:8]}`)
2. The service account is granted the **User** role for the Nexus app itself (`helios/singlestore.com/helios/nexusapps/resources/create_resource.go:1747`)
3. For ML Functions, the service account is also granted **Reader** role for the cluster (`helios/singlestore.com/helios/nexusapps/resources/create_resource.go:1754`)
4. The service account is set as the `RunAs` identity for the Nexus app (`helios/singlestore.com/helios/nexusapps/resources/create_resource.go:1763`)

### Permissions Granted to Service Account

#### At Nexus App Level
- **Role**: User (`authz.RoleUser`)
- **Permissions**:
  - Use (ability to use the Aura app)
  - Create API Keys

#### At Agent Domain Level
When a domain is created, the service account is automatically granted:
- **Role**: User (`authz.RoleUser`) for the agent domain
- **Location**: `helios/singlestore.com/helios/graph/server/public/agentdomains.go:284`
- **Permissions**:
  - Use (ability to use the domain)

This allows scheduled jobs running as the service account to access and process domain data.

## Domain Owner Permissions

### Key Finding: Domain Owners ARE Granted Owner Role on Analyst Nexus App

**Yes, domain owners are granted Owner roles on the Analyst Nexus app.**

### Implementation Details

When an agent domain is created (`helios/singlestore.com/helios/graph/server/public/agentdomains.go:266-280`):

1. **Domain Owner Role**: The creating user is granted **Owner** role for the Agent Domain (line 266)
   - Permissions: Update, Delete, Control Access, Use, View Agent Domain Feedback, View Agent Domain User Conversations

2. **Nexus App Owner Role**: The creating user is **also granted Owner role for the Aura App** (line 273)
   - **Purpose**: "Grant Aura App 'Owner' role so the domain owner can grant Aura App roles when granting domain access"
   - **Permissions**: Control Access, Create API Keys, Update, Delete, Revoke API Keys, Use

3. **Service Account Access**: The Analyst service account is granted **User** role for the domain (line 284)

### Rationale
The domain owner needs Owner permissions on the Nexus app to:
- Grant other users access to use the Analyst app within their domain
- Manage API keys for the Analyst app
- Control who can interact with the Analyst functionality

## Data Flow

### Domain Creation Flow
1. User creates an agent domain
2. System grants user Owner role on the domain
3. System grants user Owner role on the Analyst Nexus app
4. System grants service account User role on the domain
5. Scanner job is triggered to process domain data

### Domain Deletion Flow
1. User deletes an agent domain
2. System revokes user's Owner role from the domain
3. System revokes service account's User role from the domain
4. Database RBAC cleanup is performed

## API Contracts

### Key GraphQL Mutations
- `CreateAgentDomain`: Creates domain and sets up permissions
- `UpdateAgentDomain`: Updates domain configuration
- `DeleteAgentDomain`: Removes domain and cleans up permissions

## Dependencies

### Service Account Dependencies
- Requires Organization context for creation
- Depends on AuthorizationManager for role grants
- Requires valid ProjectID and NexusAppID

### Domain Owner Dependencies
- Requires Nova RBAC feature flag (`graph.FeatureFlagIDNovaRbac`)
- Depends on existing Analyst Nexus app installation
- Requires valid Organization and Project context

## Configuration

### Feature Flags
- `graph.FeatureFlagIDNovaRbac`: Enables RBAC-based permission model for domains

### Service Account Naming Convention
- Format: `{prefix}-{clusterID[:8]}`
- Example: `analyst-serviceaccount-a1b2c3d4`

## Code References

### Service Account Creation
- Service account resource definition: `singlestore-nexus/ai-apps/bot/analyst/install/install.yaml:16-20`
- Creation logic: `helios/singlestore.com/helios/nexusapps/resources/create_resource.go:1707-1767`
- Permission grants: `helios/singlestore.com/helios/nexusapps/resources/create_resource.go:1747-1758`

### Domain Owner Permissions
- Domain creation with permissions: `helios/singlestore.com/helios/graph/server/public/agentdomains.go:216-309`
- Owner role grant for Nexus app: `helios/singlestore.com/helios/graph/server/public/agentdomains.go:273-276`
- Service account domain access: `helios/singlestore.com/helios/graph/server/public/agentdomains.go:284-287`

### Permission Models
- Agent Domain YAML: `helios/singlestore.com/helios/authz/model/yaml/agentdomain.yaml`
- Aura App YAML: `helios/singlestore.com/helios/authz/model/yaml/auraapp.yaml`
- Permission constants: `helios/singlestore.com/helios/authz/permissions.go:16-87`

### Utility Functions
- Get Nexus app and service account: `helios/singlestore.com/helios/graph/server/public/agentdomains.go:149-172`
- Domain user name generation: `helios/singlestore.com/helios/graph/server/public/agentdomains.go:458-460`