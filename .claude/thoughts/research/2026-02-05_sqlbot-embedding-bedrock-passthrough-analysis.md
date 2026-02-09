---
type: research
title: SQLBot Embedding Model Analysis - Bedrock Passthrough vs Container Deployment
project: singlestore-nexus
area: inference-apis/embedding-models
tags: [sqlbot-embedding, bedrock, unified-model-gateway, nova-containers, inference-api]
date: 2026-02-05
status: complete
related_plans: []
---

# SQLBot Embedding Model Analysis: sqlbot-embedding-20260204092551

## Overview

The identifier `sqlbot-embedding-20260204092551` represents a dynamically-generated inference API name for the SQLBot embedding model. This is **not a container** but rather a **direct passthrough to Amazon Bedrock** for embedding operations. The timestamp suffix (20260204092551) indicates when this specific inference API instance was created: February 4, 2026 at 09:25:51 UTC.

## Key Components

### 1. SQLBot Embedding Configuration
- **Configuration File**: `/home/jchi/projects/singlestore-nexus/ai-apps/bot/analyst/install/install.yaml:45-50`
- **Base Name**: `sqlbot-embedding`
- **Model ID**: `text-embedding-ada-002` (OpenAI format)
- **Amazon Model**: `amazon.titan-embed-text-v1` (Bedrock)
- **Platform**: Amazon
- **Provider**: OpenAI
- **Version**: v1.2
- **Used By**: Aura Service

### 2. Dynamic Name Generation
- **Function**: `constructTimestampedName()` in `/home/jchi/projects/helios/singlestore.com/helios/nexusapps/resources/create_resource.go:178-196`
- **Pattern**: `{base-name}-{YYYYMMDDHHMMSS}`
- **Timestamp**: UTC timestamp appended during resource creation
- **Environment**: Only applies to non-dev environments (dev uses static names)

### 3. Inference API Creation Flow
- **Main Function**: `createInferenceAPIResource()` in `/home/jchi/projects/helios/singlestore.com/helios/nexusapps/resources/create_resource.go:354-503`
- **Platform Detection**: Lines 449-494 determine deployment method based on hosting platform
- **Amazon Path**: Lines 452-471 configure Amazon Bedrock parameters

## Data Flow

### Request Routing Path
```
User Request → Unified Model Gateway → Amazon Bedrock
                       ↓
              Route Resolution
           (StateSvc Cache Lookup)
                       ↓
              Bedrock Client
            (AWS SDK Integration)
                       ↓
            amazon.titan-embed-text-v1
```

### Unified Model Gateway Processing
1. **Endpoint**: `/inferenceapis/{projectID}/sqlbot-embedding-{timestamp}`
2. **Model Resolution**: `/home/jchi/projects/unified-model-gateway/singlestore.com/unified-model-gateway/internal/handlers/utils.go:103-242`
3. **Bedrock Handler**: `/home/jchi/projects/unified-model-gateway/singlestore.com/unified-model-gateway/internal/bedrock/model_wrapper.go:601-680`

## API Contracts

### OpenAI-Compatible Embedding Request
```json
{
  "model": "sqlbot-embedding-20260204092551",
  "input": ["text to embed"],
  "encoding_format": "float"
}
```

### Bedrock Conversion
- **Method**: `CallEmbedding()` converts OpenAI format to Bedrock `InvokeModel()` API
- **Content Type**: `application/json`
- **Response**: OpenAI-compatible format with vectors and token counts

## Dependencies

### Upstream Dependencies
- **StateSvc**: Model metadata and routing information
- **AWS Bedrock Runtime**: Actual embedding model execution
- **IAM Roles**: `bedrock-invocation`, `bedrock-invocation-stg`, `bedrock-invocation-pvw`

### Downstream Consumers
- **Aura Service**: Primary consumer for analyst capabilities
- **SQLBot Notebooks**: `/home/jchi/projects/singlestore-nexus/ai-apps/bot/analyst/source/sqlbot.ipynb`

## Configuration

### Environment Variables
- **Feature Flag**: `graph.FeatureFlagIDAmazonAnalyst` determines Amazon model usage
- **Rate Limiting**: Configurable requests per minute (default from LibCloudAIOpts)

### Model Selection Logic
- **Function**: `extractModelNameAndPlatform()` in `/home/jchi/projects/helios/singlestore.com/helios/nexusapps/resources/create_resource.go:419`
- **Priority**: Amazon models used when feature flag enabled, otherwise OpenAI models

## Code References

### Deployment Decision Logic
**File**: `/home/jchi/projects/helios/singlestore.com/helios/nexusapps/resources/create_resource.go:449-494`

The critical switch statement that determines deployment method:
- **Line 450**: `case aimodel.ModelHostingPlatformNova:` - Container deployment with pool allocation
- **Line 452**: `case aimodel.ModelHostingPlatformAmazon:` - **Bedrock passthrough** (used for sqlbot-embedding)
- **Line 472**: `case aimodel.ModelHostingPlatformAzure:` - Azure passthrough

### Bedrock Integration
**File**: `/home/jchi/projects/unified-model-gateway/singlestore.com/unified-model-gateway/internal/bedrock/model_wrapper.go:601-680`

Key embedding processing:
- **Line 601**: `CallEmbedding()` function entry point
- **Line 635-642**: Token encoding/decoding with tiktoken
- **Line 661**: Bedrock `InvokeModel()` API call
- **Line 673-680**: Response formatting to OpenAI structure

### Gateway Routing
**File**: `/home/jchi/projects/unified-model-gateway/singlestore.com/unified-model-gateway/internal/handlers/reverse_proxy.go:211-221`

Cloud provider routing logic:
- **Line 213**: AWS routes to Bedrock client
- **Line 216**: Azure routes via HTTP proxy
- **Line 219**: Nova routes to container URLs

### StateSvc Cache Management
**File**: `/home/jchi/projects/unified-model-gateway/singlestore.com/unified-model-gateway/internal/handlers/utils.go:103-242`

Model metadata caching:
- **Line 130-137**: `AppIDToNovaContainerInfoMap` for Nova/Aura apps
- **Line 140-145**: `UserInfoToContainerInfoMap` for user-specific models
- **Line 150**: TTL-based eviction (1-minute for Aura models)

## Key Finding: Direct Bedrock Passthrough

**sqlbot-embedding-20260204092551 is NOT a container deployment.** It operates as a direct passthrough to Amazon Bedrock:

1. **No Container Creation**: The system does not spawn any Kubernetes pods or Nova containers for this model
2. **Direct API Calls**: Requests are translated from OpenAI format and sent directly to AWS Bedrock Runtime
3. **AWS Authentication**: Uses IAM role assumption with SigV4 signing
4. **Model Location**: The actual `amazon.titan-embed-text-v1` model runs on AWS infrastructure, not in SingleStore's clusters
5. **Gateway Role**: Unified Model Gateway acts purely as a format translator and router, not a compute host

This architecture provides:
- **Lower Latency**: No container startup overhead
- **Reduced Resource Usage**: No dedicated compute allocation
- **AWS Scaling**: Leverages Amazon's managed service scaling
- **Simplified Management**: No container lifecycle to manage

## Research Complete

Report saved to: `/home/jchi/.claude/thoughts/research/2026-02-05_sqlbot-embedding-bedrock-passthrough-analysis.md`

**Next step:** To create an implementation plan based on this research:
/create-plan [describe the feature/task], referencing ~/.claude/thoughts/research/2026-02-05_sqlbot-embedding-bedrock-passthrough-analysis.md
