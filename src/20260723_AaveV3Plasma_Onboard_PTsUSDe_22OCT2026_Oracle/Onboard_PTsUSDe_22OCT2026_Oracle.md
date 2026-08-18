---
title: "Onboard_PTsUSDe_22OCT2026_Oracle"
author: "LlamaRisk"
discussions: "https://gov.discussion.placeholder"
snapshot: "Direct-to-AIP"
---

## Simple Summary

This proposal seeks to onboard the PT Oracle for PT-sUSDe-22OCT2026 to the Aave V3 Plasma Instance, enabling accurate on-chain pricing of the principal token through its maturity. This proposal will be Direct-to-AIP.

## Motivation

Pendle PT collateral has become an established use case across Aave markets, with consistent demand from users seeking fixed-rate exposure and structured yield strategies through principal tokens.

Accurate PT pricing requires a dedicated oracle that discounts the underlying asset price by the time remaining to maturity, with the discount rate tracking the implied APY of the corresponding Pendle market. The PT Oracle provides this pricing on Plasma with on-chain enforced bounds, ensuring the reported price converges to the underlying value at maturity and cannot deviate beyond governance-approved constraints.

## Specification

**PT-sUSDe-22OCT2026**

[Explorer link](https://plasmascan.to/address/0xf7fb83435f455bd970f2d9f943f4eece1941b3e9)

Maturity: 2026-10-22 00:00 UTC

### On-chain Actions

The payload performs the following actions on Aave V3 Plasma:

1. Registers an `AaveDiscountRateAgent` on the Aave-governance-owned AgentHub, consuming `PendleDiscountRateUpdate` records from the LlamaRisk Risk Oracle, restricted to the PT-sUSDe-22OCT2026 reserve.
2. Registers an `AaveEModeAgent` on the AgentHub, consuming `EModeCategoryUpdate` records from the LlamaRisk Risk Oracle, restricted to the PT-sUSDe-22OCT2026 eMode categories (25: `sUSDe_PT_sUSDe_22OCT2026__Stablecoins`, 26: `sUSDe_PT_sUSDe_22OCT2026__USDe`).
3. Grants the `RISK_ADMIN` role to both agents on the Plasma ACL Manager, allowing the discount-rate agent to update `discountRatePerYear` on the existing PT-sUSDe-22OCT2026 price cap adapter and the eMode agent to update the eMode categories via the Aave Config Engine.

Note: the AaveOracle price feed for PT-sUSDe-22OCT2026 does **not** change. The existing [PendlePriceCapAdapter](https://plasmascan.to/address/0x9c823f4e19Ef68347810a9C139619273b8282b7e) remains the price source; this proposal only enables the automated, bounds-enforced discount-rate and eMode update path behind it.

### Deployed Contracts

- LlamaRisk Risk Oracle: TBD (placeholder)
- LlamaguardRiskOracleRouter: TBD (placeholder)
- PTParameterRegistry: TBD (placeholder)
- AaveDiscountRateAgent: TBD (placeholder)
- AaveEModeAgent: TBD (placeholder)

### Risk Parameters

Risk parameters will be established by Risk Service Providers and incorporated into the updated proposal.

### Useful Links

- [Pendle PT documentation](https://docs.pendle.finance/pendle-v2/ProtocolMechanics/YieldTokenization/PT)
- [Ethena sUSDe documentation](https://docs.ethena.fi/solution-design/staked-usde-susde)

## References

- Implementation: [AaveV3Plasma](https://github.com/aave-dao/aave-proposals-v3/blob/main/src/20260723_AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle/AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723.sol)
- Tests: [AaveV3Plasma](https://github.com/aave-dao/aave-proposals-v3/blob/main/src/20260723_AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle/AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723.t.sol)
- Snapshot: Direct-to-AIP
- [Discussion](https://gov.discussion.placeholder)

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
