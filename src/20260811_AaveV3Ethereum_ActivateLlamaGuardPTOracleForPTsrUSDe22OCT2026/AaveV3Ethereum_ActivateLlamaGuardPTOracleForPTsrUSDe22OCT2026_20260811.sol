// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IProposalGenericExecutor} from 'aave-helpers/src/interfaces/IProposalGenericExecutor.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets, AaveV3EthereumEModes} from 'aave-address-book/AaveV3Ethereum.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {IACLManager} from 'aave-address-book/AaveV3.sol';
import {IAgentHub} from '../interfaces/chaos-agents/IAgentHub.sol';
import {IAgentConfigurator} from '../interfaces/chaos-agents/IAgentConfigurator.sol';
import {ILlamaGuardOracle} from '../interfaces/ILlamaGuardOracle.sol';
import {ILlamaguardRiskOracleRouter} from '../interfaces/ILlamaguardRiskOracleRouter.sol';
import {IRangeValidationModule} from '../interfaces/IRangeValidationModule.sol';
import {IRiskOracle} from '../interfaces/IRiskOracle.sol';

abstract contract LlamaGuardPTOracleActivationBase is IProposalGenericExecutor {
  struct ActivationConfig {
    address riskOracle;
    address emaOracle;
    address router;
    address discountRateAgent;
    address eModeAgent;
    bytes32 emaWorkflowId;
    bytes32 discountWorkflowId;
    bytes32 eModeWorkflowId;
  }

  uint256 public constant EXPECTED_AGENT_COUNT = 5;
  uint256 public constant DISCOUNT_AGENT_ID = 5;
  uint256 public constant EMODE_AGENT_ID = 6;

  address public constant CRE_FORWARDER = 0x0b93082D9b3C7C97fAcd250082899BAcf3af3885;
  address public constant CRE_WORKFLOW_AUTHOR = 0x73494691C9B28b91A0b4C9dF213c1893fddA3a3B;

  string public constant EMA_WORKFLOW = 'pt-ema-eth-srusde-22oct26-prod';
  string public constant DISCOUNT_WORKFLOW = 'pt-dro-eth-srusde-22oct26-prod';
  string public constant EMODE_WORKFLOW = 'pt-rpo-eth-srusde-22oct26-prod';

  // Chainlink CRE represents the first five SHA-256 bytes as ten lowercase ASCII hex bytes.
  bytes10 public constant EMA_WORKFLOW_NAME = bytes10('0a4b7adb5f');
  bytes10 public constant DISCOUNT_WORKFLOW_NAME = bytes10('f617f4f4ec');
  bytes10 public constant EMODE_WORKFLOW_NAME = bytes10('6cd8bad37c');

  string public constant DISCOUNT_UPDATE_TYPE = 'PendleDiscountRateUpdate';
  string public constant EMODE_UPDATE_TYPE = 'EModeCategoryUpdate';
  string public constant EMODE_LTV_UPDATE_TYPE = 'EModeLTV';
  string public constant EMODE_LT_UPDATE_TYPE = 'EModeLiquidationThreshold';
  string public constant EMODE_LB_UPDATE_TYPE = 'EModeLiquidationBonus';

  uint256 public constant DISCOUNT_MINIMUM_DELAY = 1 hours;
  uint256 public constant EMODE_MINIMUM_DELAY = 36 hours;
  uint256 public constant DISCOUNT_EXPIRATION_PERIOD = 2 days;
  uint256 public constant EMODE_EXPIRATION_PERIOD = 3 days;

  uint120 public constant DISCOUNT_MAX_CHANGE = 1e16;
  uint120 public constant EMODE_MAX_CHANGE_BPS = 50;

  bytes4 public constant EMA_PUBLISH_SELECTOR =
    ILlamaGuardOracle.updateLatestRiskRoundData.selector;
  bytes4 public constant DISCOUNT_PUBLISH_SELECTOR =
    IRiskOracle.publishRiskParameterUpdate.selector;
  bytes4 public constant EMODE_PUBLISH_SELECTOR =
    IRiskOracle.publishBulkRiskParameterUpdates.selector;

  error ProductionDeploymentNotConfigured(address deployment);
  error UnexpectedAgentCount(uint256 expected, uint256 actual);
  error UnexpectedAgentId(uint256 expected, uint256 actual);
  error UnexpectedOwner(address deployment, address expected, address actual);
  error MissingAdminRole(address deployment, address expectedAdmin);
  error InvalidWorkflowId(bytes32 workflowId);
  error DuplicateWorkflowId(bytes32 workflowId);

  function execute() external {
    ActivationConfig memory config = _getActivationConfig();
    _validate(config);

    IAgentHub hub = IAgentHub(MiscEthereum.AGENT_HUB);
    ILlamaguardRiskOracleRouter router = ILlamaguardRiskOracleRouter(config.router);
    IRiskOracle riskOracle = IRiskOracle(config.riskOracle);
    ILlamaGuardOracle emaOracle = ILlamaGuardOracle(config.emaOracle);

    // The Aave executor retains normal route administration. The Protocol Guardian can stop
    // reports immediately, but only the executor can unpause the Router.
    router.setUpdater(AaveV3Ethereum.ACL_ADMIN);
    router.setGuardian(MiscEthereum.PROTOCOL_GUARDIAN);

    // These write permissions are activated in the same transaction as the routes.
    if (!riskOracle.isAuthorized(config.router)) {
      riskOracle.addAuthorizedSender(config.router);
    }
    bytes32 writerRole = emaOracle.WRITER_ROLE();
    if (!emaOracle.hasWriteAccess(config.router)) {
      emaOracle.grantRole(writerRole, config.router);
    }

    // Register disabled so no agent can execute until all ranges, roles and routes exist.
    uint256 discountAgentId = hub.registerAgent(_discountAgentRegistration(config));
    if (discountAgentId != DISCOUNT_AGENT_ID) {
      revert UnexpectedAgentId(DISCOUNT_AGENT_ID, discountAgentId);
    }

    uint256 eModeAgentId = hub.registerAgent(_eModeAgentRegistration(config));
    if (eModeAgentId != EMODE_AGENT_ID) {
      revert UnexpectedAgentId(EMODE_AGENT_ID, eModeAgentId);
    }

    _configureRanges(discountAgentId, eModeAgentId);

    // The discount adapter accepts risk or pool admins. The eMode agent delegatecalls the
    // config engine and also needs RISK_ADMIN when the PoolConfigurator observes the caller.
    IACLManager(AaveV3Ethereum.ACL_MANAGER).addRiskAdmin(config.discountRateAgent);
    IACLManager(AaveV3Ethereum.ACL_MANAGER).addRiskAdmin(config.eModeAgent);

    _addRoutes(router, config, discountAgentId, eModeAgentId);

    // Final activation step. Everything above and both enable calls are atomic.
    hub.setAgentEnabled(discountAgentId, true);
    hub.setAgentEnabled(eModeAgentId, true);
  }

  function _getActivationConfig() internal view virtual returns (ActivationConfig memory);

  function _validate(ActivationConfig memory config) internal view {
    _requireContract(config.riskOracle);
    _requireContract(config.emaOracle);
    _requireContract(config.router);
    _requireContract(config.discountRateAgent);
    _requireContract(config.eModeAgent);

    _requireWorkflowId(config.emaWorkflowId);
    _requireWorkflowId(config.discountWorkflowId);
    _requireWorkflowId(config.eModeWorkflowId);
    if (config.emaWorkflowId == config.discountWorkflowId) {
      revert DuplicateWorkflowId(config.emaWorkflowId);
    }
    if (config.emaWorkflowId == config.eModeWorkflowId) {
      revert DuplicateWorkflowId(config.emaWorkflowId);
    }
    if (config.discountWorkflowId == config.eModeWorkflowId) {
      revert DuplicateWorkflowId(config.discountWorkflowId);
    }

    uint256 agentCount = IAgentHub(MiscEthereum.AGENT_HUB).getAgentCount();
    if (agentCount != EXPECTED_AGENT_COUNT) {
      revert UnexpectedAgentCount(EXPECTED_AGENT_COUNT, agentCount);
    }

    address routerOwner = ILlamaguardRiskOracleRouter(config.router).owner();
    if (routerOwner != AaveV3Ethereum.ACL_ADMIN) {
      revert UnexpectedOwner(config.router, AaveV3Ethereum.ACL_ADMIN, routerOwner);
    }

    address riskOracleOwner = IRiskOracle(config.riskOracle).owner();
    if (riskOracleOwner != AaveV3Ethereum.ACL_ADMIN) {
      revert UnexpectedOwner(config.riskOracle, AaveV3Ethereum.ACL_ADMIN, riskOracleOwner);
    }

    if (!ILlamaGuardOracle(config.emaOracle).hasRole(bytes32(0), AaveV3Ethereum.ACL_ADMIN)) {
      revert MissingAdminRole(config.emaOracle, AaveV3Ethereum.ACL_ADMIN);
    }
  }

  function _discountAgentRegistration(
    ActivationConfig memory config
  ) internal pure returns (IAgentConfigurator.AgentRegistrationInput memory input) {
    address[] memory allowedMarkets = new address[](1);
    allowedMarkets[0] = AaveV3EthereumAssets.PT_srUSDe_22OCT2026_UNDERLYING;

    input = IAgentConfigurator.AgentRegistrationInput({
      admin: AaveV3Ethereum.ACL_ADMIN,
      riskOracle: config.riskOracle,
      isAgentEnabled: false,
      isAgentPermissioned: false,
      isMarketsFromAgentEnabled: false,
      agentAddress: config.discountRateAgent,
      expirationPeriod: DISCOUNT_EXPIRATION_PERIOD,
      minimumDelay: DISCOUNT_MINIMUM_DELAY,
      updateType: DISCOUNT_UPDATE_TYPE,
      agentContext: bytes(''),
      allowedMarkets: allowedMarkets,
      restrictedMarkets: new address[](0),
      permissionedSenders: new address[](0)
    });
  }

  function _eModeAgentRegistration(
    ActivationConfig memory config
  ) internal pure returns (IAgentConfigurator.AgentRegistrationInput memory input) {
    address[] memory allowedMarkets = new address[](2);
    allowedMarkets[0] = address(
      uint160(AaveV3EthereumEModes.sUSDe_PT_srUSDe_22OCT2026__USDC_USDT_USDe)
    );
    allowedMarkets[1] = address(uint160(AaveV3EthereumEModes.sUSDe_PT_srUSDe_22OCT2026__USDe));

    input = IAgentConfigurator.AgentRegistrationInput({
      admin: AaveV3Ethereum.ACL_ADMIN,
      riskOracle: config.riskOracle,
      isAgentEnabled: false,
      isAgentPermissioned: false,
      isMarketsFromAgentEnabled: false,
      agentAddress: config.eModeAgent,
      expirationPeriod: EMODE_EXPIRATION_PERIOD,
      minimumDelay: EMODE_MINIMUM_DELAY,
      updateType: EMODE_UPDATE_TYPE,
      agentContext: abi.encode(AaveV3Ethereum.CONFIG_ENGINE),
      allowedMarkets: allowedMarkets,
      restrictedMarkets: new address[](0),
      permissionedSenders: new address[](0)
    });
  }

  function _configureRanges(uint256 discountAgentId, uint256 eModeAgentId) internal {
    IRangeValidationModule rangeModule = IRangeValidationModule(
      MiscEthereum.RANGE_VALIDATION_MODULE
    );

    rangeModule.setRangeConfigByMarket(
      MiscEthereum.AGENT_HUB,
      discountAgentId,
      AaveV3EthereumAssets.PT_srUSDe_22OCT2026_UNDERLYING,
      DISCOUNT_UPDATE_TYPE,
      IRangeValidationModule.RangeConfig({
        maxIncrease: DISCOUNT_MAX_CHANGE,
        maxDecrease: DISCOUNT_MAX_CHANGE,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );

    IRangeValidationModule.RangeConfig memory eModeRange = IRangeValidationModule.RangeConfig({
      maxIncrease: EMODE_MAX_CHANGE_BPS,
      maxDecrease: EMODE_MAX_CHANGE_BPS,
      isIncreaseRelative: false,
      isDecreaseRelative: false
    });

    rangeModule.setDefaultRangeConfig(
      MiscEthereum.AGENT_HUB,
      eModeAgentId,
      EMODE_LTV_UPDATE_TYPE,
      eModeRange
    );
    rangeModule.setDefaultRangeConfig(
      MiscEthereum.AGENT_HUB,
      eModeAgentId,
      EMODE_LT_UPDATE_TYPE,
      eModeRange
    );
    rangeModule.setDefaultRangeConfig(
      MiscEthereum.AGENT_HUB,
      eModeAgentId,
      EMODE_LB_UPDATE_TYPE,
      eModeRange
    );
  }

  function _addRoutes(
    ILlamaguardRiskOracleRouter router,
    ActivationConfig memory config,
    uint256 discountAgentId,
    uint256 eModeAgentId
  ) internal {
    router.addRoute(
      config.emaWorkflowId,
      CRE_FORWARDER,
      CRE_WORKFLOW_AUTHOR,
      EMA_WORKFLOW_NAME,
      config.emaOracle,
      EMA_PUBLISH_SELECTOR,
      address(0),
      new uint256[](0)
    );

    uint256[] memory discountAgentIds = new uint256[](1);
    discountAgentIds[0] = discountAgentId;
    router.addRoute(
      config.discountWorkflowId,
      CRE_FORWARDER,
      CRE_WORKFLOW_AUTHOR,
      DISCOUNT_WORKFLOW_NAME,
      config.riskOracle,
      DISCOUNT_PUBLISH_SELECTOR,
      MiscEthereum.AGENT_HUB,
      discountAgentIds
    );

    uint256[] memory eModeAgentIds = new uint256[](1);
    eModeAgentIds[0] = eModeAgentId;
    router.addRoute(
      config.eModeWorkflowId,
      CRE_FORWARDER,
      CRE_WORKFLOW_AUTHOR,
      EMODE_WORKFLOW_NAME,
      config.riskOracle,
      EMODE_PUBLISH_SELECTOR,
      MiscEthereum.AGENT_HUB,
      eModeAgentIds
    );

    // Router max-step is disabled (0): the AgentHub range module is the authoritative absolute
    // step cap. The discount route duplicates the one-hour cadence as defense in depth.
    router.setRouteThrottle(config.emaWorkflowId, 0, 0);
    router.setRouteThrottle(config.discountWorkflowId, uint64(DISCOUNT_MINIMUM_DELAY), 0);
    router.setRouteThrottle(config.eModeWorkflowId, 0, 0);
  }

  function _requireContract(address deployment) internal view {
    if (deployment == address(0) || deployment.code.length == 0) {
      revert ProductionDeploymentNotConfigured(deployment);
    }
  }

  function _requireWorkflowId(bytes32 workflowId) internal pure {
    if (workflowId == bytes32(0)) revert InvalidWorkflowId(workflowId);
  }
}

/**
 * @title Activate LlamaGuard PT Oracle for PT-srUSDe-22OCT2026
 * @author LlamaRisk
 * - Snapshot: Direct-to-AIP
 * - Discussion: https://outline.llamarisk.com/doc/ethereum-pt-srusde-staging-0826-6axP9W0Pdy
 */
contract AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811 is
  LlamaGuardPTOracleActivationBase
{
  // Fill these eight values after the production contracts and CRE workflows are deployed.
  address public constant LLAMARISK_RISK_ORACLE = address(0);
  address public constant LLAMAGUARD_EMA_ORACLE = address(0);
  address public constant LLAMAGUARD_ROUTER = address(0);
  address public constant DISCOUNT_RATE_AGENT = address(0);
  address public constant EMODE_AGENT = address(0);

  bytes32 public constant EMA_WORKFLOW_ID = bytes32(0);
  bytes32 public constant DISCOUNT_WORKFLOW_ID = bytes32(0);
  bytes32 public constant EMODE_WORKFLOW_ID = bytes32(0);

  function _getActivationConfig() internal pure override returns (ActivationConfig memory) {
    return
      ActivationConfig({
        riskOracle: LLAMARISK_RISK_ORACLE,
        emaOracle: LLAMAGUARD_EMA_ORACLE,
        router: LLAMAGUARD_ROUTER,
        discountRateAgent: DISCOUNT_RATE_AGENT,
        eModeAgent: EMODE_AGENT,
        emaWorkflowId: EMA_WORKFLOW_ID,
        discountWorkflowId: DISCOUNT_WORKFLOW_ID,
        eModeWorkflowId: EMODE_WORKFLOW_ID
      });
  }
}
