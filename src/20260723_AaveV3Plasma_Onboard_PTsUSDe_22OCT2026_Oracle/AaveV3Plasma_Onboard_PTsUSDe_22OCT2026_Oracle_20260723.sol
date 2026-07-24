// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IProposalGenericExecutor} from 'aave-helpers/src/interfaces/IProposalGenericExecutor.sol';
import {AaveV3Plasma, AaveV3PlasmaAssets, AaveV3PlasmaEModes} from 'aave-address-book/AaveV3Plasma.sol';
import {MiscPlasma} from 'aave-address-book/MiscPlasma.sol';
import {IACLManager} from 'aave-address-book/AaveV3.sol';
import {IAgentHub} from '../interfaces/chaos-agents/IAgentHub.sol';
import {IAgentConfigurator} from '../interfaces/chaos-agents/IAgentConfigurator.sol';

/**
 * @title Onboard_PTsUSDe_22OCT2026_Oracle
 * @author LlamaRisk
 * - Snapshot: Direct-to-AIP
 * - Discussion: https://gov.discussion.placeholder
 */
contract AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723 is IProposalGenericExecutor {
  // LlamaRisk production deployments on Plasma mainnet (llamaguard-risk-oracles stack)
  // TODO: replace placeholders with the deployed addresses

  // BGD stock RiskOracle fed by the LlamaguardRiskOracleRouter (CRE discount-rate / risk-params workflows)
  address public constant LLAMARISK_RISK_ORACLE = 0x0000000000000000000000000000000000000000;
  // AaveDiscountRateAgent(MiscPlasma.AGENT_HUB, MiscPlasma.RANGE_VALIDATION_MODULE, "", AaveV3Plasma.POOL, AaveV3Plasma.ORACLE)
  address public constant DISCOUNT_RATE_AGENT = 0x0000000000000000000000000000000000000000;
  // AaveEModeAgent(MiscPlasma.AGENT_HUB, MiscPlasma.RANGE_VALIDATION_MODULE, "", AaveV3Plasma.POOL)
  address public constant EMODE_AGENT = 0x0000000000000000000000000000000000000000;
  // LlamaRisk operations multisig, allowed to manage agent markets / senders / range configs
  address public constant AGENT_ADMIN = 0x0000000000000000000000000000000000000000;

  string public constant DISCOUNT_UPDATE_TYPE = 'PendleDiscountRateUpdate';
  string public constant EMODE_UPDATE_TYPE = 'EModeCategoryUpdate';

  uint256 public constant EXPIRATION_PERIOD = 365 days;
  uint256 public constant MINIMUM_DELAY = 0; // TODO: confirm with risk methodology

  function execute() external {
    // 1. Register the discount-rate agent on the Aave-owned AgentHub, consuming
    //    PendleDiscountRateUpdate records from the LlamaRisk RiskOracle for PT-sUSDe-22OCT2026
    address[] memory ptMarkets = new address[](1);
    ptMarkets[0] = AaveV3PlasmaAssets.PT_sUSDE_22OCT2026_UNDERLYING;

    IAgentHub(MiscPlasma.AGENT_HUB).registerAgent(
      IAgentConfigurator.AgentRegistrationInput({
        admin: AGENT_ADMIN,
        riskOracle: LLAMARISK_RISK_ORACLE,
        isAgentEnabled: true,
        isAgentPermissioned: false,
        isMarketsFromAgentEnabled: false,
        agentAddress: DISCOUNT_RATE_AGENT,
        expirationPeriod: EXPIRATION_PERIOD,
        minimumDelay: MINIMUM_DELAY,
        updateType: DISCOUNT_UPDATE_TYPE,
        agentContext: bytes(''),
        allowedMarkets: ptMarkets,
        restrictedMarkets: new address[](0),
        permissionedSenders: new address[](0)
      })
    );

    // 2. Register the eMode agent for the PT-sUSDe-22OCT2026 eMode categories
    //    (eMode ids are encoded as addresses, chaos-agents convention)
    address[] memory eModeMarkets = new address[](2);
    eModeMarkets[0] = address(uint160(AaveV3PlasmaEModes.sUSDe_PT_sUSDE_22OCT2026__USDT0_USDe_GHO));
    eModeMarkets[1] = address(uint160(AaveV3PlasmaEModes.sUSDe_PT_sUSDE_22OCT2026__USDe));

    IAgentHub(MiscPlasma.AGENT_HUB).registerAgent(
      IAgentConfigurator.AgentRegistrationInput({
        admin: AGENT_ADMIN,
        riskOracle: LLAMARISK_RISK_ORACLE,
        isAgentEnabled: true,
        isAgentPermissioned: false,
        isMarketsFromAgentEnabled: false,
        agentAddress: EMODE_AGENT,
        expirationPeriod: EXPIRATION_PERIOD,
        minimumDelay: MINIMUM_DELAY,
        updateType: EMODE_UPDATE_TYPE,
        // the eMode agent delegatecalls updateEModeCategories on the target decoded from its context
        agentContext: abi.encode(AaveV3Plasma.CONFIG_ENGINE),
        allowedMarkets: eModeMarkets,
        restrictedMarkets: new address[](0),
        permissionedSenders: new address[](0)
      })
    );

    // 3. Grant RISK_ADMIN so the discount agent can call setDiscountRatePerYear() on the
    //    existing PT-sUSDe-22OCT2026 PendlePriceCapAdapter and the eMode agent can update
    //    the eMode categories via the pool configurator (mirror of the Chaos offboarding)
    IACLManager(AaveV3Plasma.ACL_MANAGER).addRiskAdmin(DISCOUNT_RATE_AGENT);
    IACLManager(AaveV3Plasma.ACL_MANAGER).addRiskAdmin(EMODE_AGENT);
  }
}
