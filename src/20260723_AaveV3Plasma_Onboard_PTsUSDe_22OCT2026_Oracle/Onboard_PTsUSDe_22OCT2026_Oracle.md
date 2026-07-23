---
title: "Onboard_PTsUSDe_22OCT2026_Oracle"
author: "LlamaRisk"
discussions: "https://gov.discussion.placeholder"
snapshot: "https://gove.snapshot.placeholder"
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

### Risk Parameters

Risk parameters will be established by Risk Service Providers and incorporated into the updated proposal.

### Useful Links

- [Pendle PT documentation](https://docs.pendle.finance/pendle-v2/ProtocolMechanics/YieldTokenization/PT)
- [Ethena sUSDe documentation](https://docs.ethena.fi/solution-design/staked-usde-susde)

## References

- Implementation: [AaveV3Plasma](https://github.com/aave-dao/aave-proposals-v3/blob/main/src/20260723_AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle/AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723.sol)
- Tests: [AaveV3Plasma](https://github.com/aave-dao/aave-proposals-v3/blob/main/src/20260723_AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle/AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723.t.sol)
- [Snapshot](https://gove.snapshot.placeholder)
- [Discussion](https://gov.discussion.placeholder)

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
