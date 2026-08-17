---
title: "Activate LlamaGuard PT Oracle for PT-srUSDe-22OCT2026"
author: "LlamaRisk"
discussions: "https://outline.llamarisk.com/doc/ethereum-pt-srusde-staging-0826-6axP9W0Pdy"
snapshot: "Direct-to-AIP"
---

## Simple Summary

Activate LlamaGuard's automated discount-rate and eMode update paths for PT-srUSDe-22OCT2026 on Aave V3 Ethereum Core.

This proposal does not replace the reserve's price feed. The existing `PendlePriceCapAdapter` remains the Aave Oracle source. LlamaGuard supplies bounded updates to the adapter's `discountRatePerYear` and to the two eMode categories containing the reserve.

## Motivation

PT-srUSDe-22OCT2026 is priced using a linear discount that converges to the underlying asset price at maturity. Keeping the discount aligned with the Pendle market requires recurring updates. The corresponding eMode parameters also depend on the PT's evolving price and time to maturity.

The production LlamaGuard deployment uses three Chainlink CRE workflows:

- an EMA workflow that writes Pendle market observations to the LlamaGuard EMA oracle;
- a discount-rate workflow that writes `PendleDiscountRateUpdate` records to a fresh RiskOracle; and
- a risk-parameter workflow that writes `EModeCategoryUpdate` batches to the same RiskOracle.

The LlamaGuard Router validates each workflow's ID, Forwarder, author, and name. Discount and eMode records then pass through Aave's AgentHub, which enforces market allowlists, cooldowns, expiration periods, and absolute range limits before either production agent can write to Aave.

## Specification

### Affected reserve

| Field                  | Value                                                                                                                   |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Aave instance          | Ethereum Core                                                                                                           |
| Reserve                | PT-srUSDe-22OCT2026 (reserve id 66)                                                                                     |
| Asset                  | [`0x59bC9FaE5D62B19d4f8d07D758047aCb9EE19d34`](https://etherscan.io/address/0x59bC9FaE5D62B19d4f8d07D758047aCb9EE19d34) |
| Maturity               | 2026-10-22 00:00 UTC                                                                                                    |
| Existing price adapter | [`0xBD1bc41479D0b58167584980fE57fDA913d4fB73`](https://etherscan.io/address/0xBD1bc41479D0b58167584980fE57fDA913d4fB73) |
| eMode categories       | 47 (`PT-srUSDe Stablecoins`) and 48 (`PT-srUSDe USDe`)                                                                  |

### Agent configuration

The payload requires the Ethereum AgentHub count to equal `5`. It then registers the discount-rate agent as ID `5` and the eMode agent as ID `6`. If either ID is unavailable at execution time, the entire payload reverts.

Both agents are registered disabled. They are enabled only after all permissions, ranges, and Router routes have been configured in the same atomic transaction.

| Parameter                  | Value                        |
| -------------------------- | ---------------------------- |
| Discount update cooldown   | 1 hour                       |
| eMode update cooldown      | 36 hours                     |
| Discount update expiration | 48 hours                     |
| eMode update expiration    | 72 hours                     |
| Discount maximum step      | 1 percentage point, absolute |
| eMode maximum step         | 50 bps per field, absolute   |

The eMode range applies separately to LTV, liquidation threshold, and liquidation bonus. The Router's relative maximum-step check remains disabled because AgentHub's absolute range validation is the authoritative cap. The Router duplicates the one-hour discount cadence as defense in depth.

### Workflow routes

All three production workflows are deployed before proposal submission. Their workflow IDs are inserted into the payload together with the five fresh production contract addresses.

| Workflow name                    | Router target         | AgentHub action |
| -------------------------------- | --------------------- | --------------- |
| `pt-ema-eth-srusde-22oct26-prod` | LlamaGuard EMA oracle | none            |
| `pt-dro-eth-srusde-22oct26-prod` | LlamaRisk RiskOracle  | agent ID 5      |
| `pt-rpo-eth-srusde-22oct26-prod` | LlamaRisk RiskOracle  | agent ID 6      |

The expected CRE Forwarder is `0x0b93082D9b3C7C97fAcd250082899BAcf3af3885`, and the expected workflow author is `0x73494691C9B28b91A0b4C9dF213c1893fddA3a3B`.

Before this AIP executes, the Router has no routes for these workflow IDs. CRE runs therefore cannot publish through the Router or change Aave state. Once the AIP executes, subsequent eligible workflow runs use the newly activated routes. Discount and eMode publication may wait for the production EMA workflow to accumulate the observations required by their methodology.

### On-chain actions

The payload makes the following state-changing calls in order:

1. `Router.setUpdater(AAVE_EXECUTOR)`.
2. `Router.setGuardian(AAVE_PROTOCOL_GUARDIAN)`.
3. `RiskOracle.addAuthorizedSender(Router)` if the Router is not already authorized.
4. `EMAOracle.grantRole(WRITER_ROLE, Router)` if the Router does not already have write access.
5. `AgentHub.registerAgent(discountConfigDisabled)` and require returned ID `5`.
6. `AgentHub.registerAgent(eModeConfigDisabled)` and require returned ID `6`.
7. `RangeValidationModule.setRangeConfigByMarket(...)` for the discount update.
8. `RangeValidationModule.setDefaultRangeConfig(...)` for eMode LTV.
9. `RangeValidationModule.setDefaultRangeConfig(...)` for eMode liquidation threshold.
10. `RangeValidationModule.setDefaultRangeConfig(...)` for eMode liquidation bonus.
11. `ACLManager.addRiskAdmin(discountAgent)`.
12. `ACLManager.addRiskAdmin(eModeAgent)`.
13. `Router.addRoute(...)` for the EMA workflow.
14. `Router.addRoute(...)` for the discount workflow and agent ID `5`.
15. `Router.addRoute(...)` for the eMode workflow and agent ID `6`.
16. `Router.setRouteThrottle(...)` for each of the three routes.
17. `AgentHub.setAgentEnabled(5, true)`.
18. `AgentHub.setAgentEnabled(6, true)`.

The payload also checks that all five production addresses contain code, all three workflow IDs are nonzero and unique, the Router and RiskOracle are owned by the Aave Ethereum executor, and the executor holds the EMA oracle's default admin role.

### Ownership and emergency control

- The Aave Ethereum executor owns the Router and RiskOracle and administers the EMA oracle.
- The executor is the Router updater and controls route parameters and enablement.
- The Aave Ethereum Protocol Guardian can pause the Router. Only the executor can unpause it.
- The Aave Ethereum executor is the administrator of both AgentHub registrations.
- No LlamaRisk EOA or deployer retains governance-level ownership in this activation payload.

### Deployment and governance sequence

1. Deploy and verify a fresh production RiskOracle, EMA oracle, Router, parameter registry, discount agent, and eMode agent. Configure their immutable Aave references and transfer/administer governance-owned contracts as required by the payload preconditions.
2. Deploy the three production CRE workflows using predicted AgentHub IDs `5` and `6`. The workflows may run during governance, but cannot publish through the unconfigured Router.
3. Insert the five production contract addresses and three production workflow IDs into the payload. Run the full fork suite and reconfirm that the live AgentHub count is still `5`.
4. Submit and execute the AIP. Execution atomically installs permissions, registers/configures IDs `5` and `6`, installs all three routes, and enables both agents.
5. Monitor the first successful EMA, discount, and eMode production runs and the resulting on-chain state.

If another governance action consumes AgentHub ID `5` before execution, this payload safely reverts and must be rebuilt with the new consecutive IDs and matching CRE workflow configurations.

## References

- [Ethereum deployment note](https://outline.llamarisk.com/doc/ethereum-pt-srusde-staging-0826-6axP9W0Pdy)
- [LlamaGuard implementation](https://github.com/llama-risk/llamaguard-risk-oracles)
- [Related Plasma activation draft](https://github.com/llama-risk/aave-proposals-v3/pull/2)
- [Pendle PT documentation](https://docs.pendle.finance/pendle-v2/ProtocolMechanics/YieldTokenization/PT)
- [Aave Pendle price adapter](https://github.com/aave-dao/aave-price-feeds/blob/main/src/contracts/PendlePriceCapAdapter.sol)

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
