---
title: Azure Route Server Next Hop IP Fast Failover
description: Extend your on-premises subnets into Azure using Linux
services: virtualnetwork
author: chriselleman-msft

ms.service: virtualnetwork
ms.topic: conceptual
ms.date: 08/08/2022
ms.author: chriselleman-msft

---

Azure Route Server Next Hop IP Fast Failover
==============


>Applies to: Azure, Linux, Route Server

# 1. _Architecture Overview_

  ![Overview Architecture showing an customer VNET networks with a single subnet, with route server attached, along with 2 webservers with a floating IP a watcher/syslog server, and a load injector](docs/overview-architecture.png)

  *Figure 1: Architecture Overview.*

# 2. Implementation
## 2.1 Planning

Before building the environment, it is important to plan out the basics which are listed in the table below:

| Variable | Purpose | Value |
| --- | --- | --- |
| Azure_VNET | The CIDR of the VNET during testing | 10.0.10.0/24 |
| Azure_Default_Subnet | The CIDR of the subnet within the VNET - we will use the whole range | 10.0.10.0/24 |
| VIP | The virtual IP (VIP) which will be shared between the 2 webservers | 10.0.15.15/32 |
| WS1_Hostname | Hostname of VM Webserver 1 | ws1 |
| WS1_IP | IP of VM Webserver 1 | 10.0.10.4 |
| WS2_Hostname | Hostname of VM Webserver 2 | ws2 |
| WS2_IP | IP of VM Webserver 2 | 10.0.10.5 |
| LT_Hostname | Hostname of LoadTest VM | lt1 |
| LT_IP | IP of LoadTest VM | 10.0.10.6 |
| Watch_Hostname | Hostname of Watcher VM | watch1 |
| Watch_IP | IP of Watcher VM | 10.0.10.7 |

## 2.2 CLI Configure

Login to Azure CLI - I typically do this using the powershell terminal from VS Code
```dotnetcli
az login
```

Set environment variables
```dotnetcli
Azure_VNET=10.0.10.0/24
Azure_Default_Subnet=10.0.10.0/24
VIP=10.0.15.15/32
WS1_Hostname=ws1
WS1_IP=10.0.10.4
WS2_Hostname=ws2
WS2_IP=10.0.10.5
LT_Hostname=lt1
LT_IP=10.0.10.6
Watch_Hostname=watch1
Watch_IP=10.0.10.7
```
