# Grafana datasource catalog

Org 1 on `grafana.aws-virginia-hm1.svc.singlestore.com`. Refresh with `list_datasources` if a UID fails.

Do not enumerate `monitoringdb-*` UIDs here (90+ per-cluster S2 monitoring DBs). Name pattern: `monitoringdb-<clusterUUID>%`.

## Postgres (`grafana-postgresql-datasource`)

| Name | UID | DB | Host hint | Use |
|---|---|---|---|---|
| postgres/helios-prd-ro | `c1f98863-a36a-4232-9261-751710e34223` | `freya` | `heliosdb-prd-1` us-east-1 | **Default** Helios control plane RO |
| postgres/heliosdb-prd-us-east-1-ro | `dekczowa0prlsd` | `freya` | Aurora cluster-ro us-east-1 | Same `freya` if prd-1 is unhappy |
| postgres/heliosdb-prd-us-east-2-ro | `dekczgbft5x4wf` | `freya` | Aurora cluster-ro us-east-2 | Regional replica |
| postgres/helios-stg-ro | `f810fdcc-bdee-42fe-9b70-0a4e61b7fcdd` | `freya` | staging | Staging control plane |
| Postgres/helios-pvw-ro | `be3pf2xaeibcwc` | `freya` | `heliosdb-preview-ro` | Preview |
| postgres/heliosdb-stg-us-east-1 | `cedjo9a94y70gc` | `freya` | stg us-east-1 | Staging regional |
| postgres/heliosdb-stg-us-east-2-ro | `cedjlh40jqrcwa` | `freya` | stg us-east-2 | Staging regional |
| postgres/helios-impact-dashboard | `aedh0yd4bypdsf` | `freya` | same prd-1 host, user `impact_dashboard` | Impact dashboard role only |
| postgres/customer-grafana-prd-us-east-1-ro | `fekczugcdfzswc` | `grafana` | grafana-prd-cluster | Customer Grafana metadata, not Helios orgs |
| postgres/customer-grafana-prd-us-east-2-ro | `cekd07ko88wsgc` | `grafana` | | same, us-east-2 |
| postgres/customer-grafana-stg-us-east-1 | `aedne3rnacp34b` | `grafana` | | staging Grafana |
| postgres/customer-grafana-stg-us-east-2 | `dedne7z6dltz4a` | `grafana` | | staging Grafana |

`freya` tables that come up in RCA: `organizations`, `groups`, `projects`, `tasks`, `notebookcodeservice`, `modelasaservice`, `schedulednotebookjobs`, `agentdomains`.

## MySQL (SingleStore behind Grafana MySQL plugin)

Same DML host can serve **different databases**. The `(helios)` suffix is the `helios` DB (nexus apps). Unsuffixed `kubera-*` is the `kubera` billing DB.

| Name | UID | DB | Use |
|---|---|---|---|
| kubera-prod | `a0b11825-21e0-4ca5-a8fd-d21c2d76c080` | `kubera` | `resourceusage`, `meterprice`, `customer` |
| kubera-prod (helios) | `cew6je1mdqqyoe` | `helios` | `nexusapps`, `nexusappversions` |
| kubera-staging | `c1820943-9f05-4e7d-9ad9-5df3e8b2f4b6` | `kubera` | staging billing |
| kubera-staging (helios) | `bew6l362a5vcwb` | `helios` | staging nexus apps |
| kubera-preview | `cew6rkd4aik1sa` | `kubera` | preview billing |
| kubera-preview (helios) | `bew6jiibzwnwgc` | `helios` | preview nexus apps |
| helios-staging | `aew63wwqjwruoc` | | staging S2 (confirm DB via `get_datasource`) |
| pulse/aura-telemetry | `bfoprho3fc54we` | `pulse` | Analyst Pulse OTel store (Grafana path) |
| pulse/aura-telemetry-claude-ai-eval | `dfs6b1ivef1moa` | `pulse` | eval Pulse |
| pulse/bigbrain | `cfw5165bexb0gb` | `pulse` | BigBrain Pulse |
| pulse/gen-ai-stg | `dfxkp8awp87b4e` | `pulse` | staging Pulse |
| sharehouse/MS2 | `e063b62e-66b7-47f7-845c-f7a117e7c872` | | Sharehouse |
| Sharehouse/public | `eej0hcno0cdmoc` | | Sharehouse public |
| tanka_sharehouse | `de0jq3zmnk740f` | | Tanka Sharehouse |
| AI Evaluation | `dexflwdpwlxc0f` | | AI eval |
| claude ai evaluation | `cf76mrps1c740c` | | Claude eval |
| mysql | `bfcbenka6i9s0b` | | generic — skip unless named |
| mysql-virginia-hd2 | `ee6dsqxof5g5cd` | | HD2 |
| telemetry-* | look up | | per-workspace telemetry |

Host for kubera-prod pair: `svc-17643b2b-50cf-4293-9fa1-812746cf4015-dml.aws-virginia-5.svc.singlestore.com`.

## Loki

| Name | UID | Notes |
|---|---|---|
| loki/helios | `f559aee0-88c1-4151-b9ec-499efb79b6a1` | **Default.** Query frontend. Tenant via `X-Scope-OrgID`. |
| loki/system | `e96092a3-6a47-4d59-ad5c-158325384883` | Same frontend, different tenant. Prefer helios. |
| loki/helios-pvw | `ae9a55rgdiz9cb` | Preview Helios logs |
| loki/psyduck | `dfx5gdmcyi8zka` | Psyduck |
| loki/aws-bootstrap-cell | `be1uc83u1m5tsf` | Cell Loki |
| loki/aws-nimbus-11 | `e46fcbfc-5575-4096-87e2-106eb9db2c8d` | Nimbus cell |
| loki/aws-nimbus-13 | `de7636e4-1624-488b-abb7-834aa735399b` | |
| loki/aws-nimbus-hd2 | `ce6tgbwrphywwd` | |
| loki/aws-nimbus-hd3 | `ce1mkl9lr6oe8b` | |
| loki/aws-nimbus-hd5 | `df9a5468-847a-4ab0-90bd-8768b99e548a` | |
| loki/aws-byoc-s2-prd1 | `feswc5gz0p1j4a` | BYOC |
| loki/aws-byoc-s2-pvw1 | `aeh3uk95p2k8wd` | |
| loki/aws-byoc-s2-stg1 | `beh3rtxbrrshsd` | |
| loki/aws-byoc-soci-prd1 | `fec0xzh99ajuob` | |
| loki/aws-byoc-unit21-prd2 | `bemkqncbicav4a` | |
| loki/aws-byoc-unit21-prd3 | `femkqq75xc9hca` | |
| loki/aws-byoc-unit21-prd4 | `eemros0ag8nb4c` | |
| loki/aws-byoc-vt-prd1 | `bej22s1vq3awwd` | |
| loki/aws-byoc-vt-stg1 | `febkvu6350s8wa` | |
| loki/aws-virginia-byoc-socipoc1 | `bdw0bhnm6mu4gc` | |

`loki/helios` labels that are cheap matchers: `cell`, `namespace`, `app`, `container`, `component`, `job`, `level`, `instance`, `service_name`. Do not match on `__stream_shard__`.

Nova Analyst/UMG default cell: `aws-virginia-novaprd1`. Namespace: `fission` (plus tenant `fission-<id>` / `nova-*` — do not regex-scan those without a project). Helios control plane namespace: `helios-prd`.
