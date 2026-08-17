// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Ethereum, AaveV3EthereumAssets, AaveV3EthereumEModes} from 'aave-address-book/AaveV3Ethereum.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';

import 'forge-std/Test.sol';
import {ProtocolV3TestBase} from 'aave-helpers/src/ProtocolV3TestBase.sol';
import {GovV3Helpers} from 'aave-helpers/src/GovV3Helpers.sol';
import {AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811, LlamaGuardPTOracleActivationBase} from './AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811.sol';
import {IAgentHub} from '../interfaces/chaos-agents/IAgentHub.sol';
import {ILlamaguardRiskOracleRouter} from '../interfaces/ILlamaguardRiskOracleRouter.sol';
import {IRangeValidationModule} from '../interfaces/IRangeValidationModule.sol';

interface IAaveAgentDeployment {
  function AGENT_HUB() external view returns (address);

  function RANGE_VALIDATION_MODULE() external view returns (address);

  function POOL() external view returns (address);

  function AAVE_ORACLE() external view returns (address);

  function getUpdateType() external view returns (string memory);
}

contract MockRiskOracle {
  address public immutable owner;
  mapping(address => bool) internal _authorized;

  constructor(address owner_) {
    owner = owner_;
  }

  function addAuthorizedSender(address sender) external {
    require(msg.sender == owner, 'ONLY_OWNER');
    require(!_authorized[sender], 'ALREADY_AUTHORIZED');
    _authorized[sender] = true;
  }

  function isAuthorized(address sender) external view returns (bool) {
    return _authorized[sender];
  }
}

contract MockEmaOracle {
  bytes32 public constant WRITER_ROLE = keccak256('WRITER_ROLE');
  mapping(bytes32 => mapping(address => bool)) internal _roles;

  constructor(address admin) {
    _roles[bytes32(0)][admin] = true;
  }

  function hasRole(bytes32 role, address account) external view returns (bool) {
    return _roles[role][account];
  }

  function grantRole(bytes32 role, address account) external {
    require(_roles[bytes32(0)][msg.sender], 'MISSING_ADMIN');
    _roles[role][account] = true;
  }

  function hasWriteAccess(address account) external view returns (bool) {
    return _roles[WRITER_ROLE][account];
  }
}

contract MockRouter {
  struct Route {
    address riskOracle;
    bytes4 publishSelector;
    address agentHub;
    uint256[] agentIds;
    bool enabled;
    uint64 minDelaySeconds;
    uint64 maxStepBps;
  }

  address public immutable owner;
  address public updater;
  address public guardian;
  mapping(bytes32 => Route) public routes;
  mapping(bytes32 => ILlamaguardRiskOracleRouter.WorkflowConfig) internal _workflowConfigs;

  constructor(address owner_) {
    owner = owner_;
  }

  function setUpdater(address newUpdater) external {
    require(msg.sender == owner, 'ONLY_OWNER');
    updater = newUpdater;
  }

  function setGuardian(address newGuardian) external {
    require(msg.sender == owner, 'ONLY_OWNER');
    guardian = newGuardian;
  }

  function addRoute(
    bytes32 workflowId,
    address forwarder,
    address author,
    bytes10 workflowName,
    address riskOracle,
    bytes4 publishSelector,
    address agentHub,
    uint256[] calldata agentIds
  ) external {
    require(msg.sender == owner, 'ONLY_OWNER');
    require(routes[workflowId].riskOracle == address(0), 'ROUTE_EXISTS');

    Route storage route = routes[workflowId];
    route.riskOracle = riskOracle;
    route.publishSelector = publishSelector;
    route.agentHub = agentHub;
    route.agentIds = agentIds;
    route.enabled = true;
    _workflowConfigs[workflowId] = ILlamaguardRiskOracleRouter.WorkflowConfig({
      expectedForwarder: forwarder,
      expectedAuthor: author,
      expectedWorkflowName: workflowName,
      isActive: true
    });
  }

  function setRouteThrottle(
    bytes32 workflowId,
    uint64 minDelaySeconds,
    uint64 maxStepBps
  ) external {
    require(msg.sender == updater, 'ONLY_UPDATER');
    require(routes[workflowId].riskOracle != address(0), 'NO_ROUTE');
    routes[workflowId].minDelaySeconds = minDelaySeconds;
    routes[workflowId].maxStepBps = maxStepBps;
  }

  function getAgentIds(bytes32 workflowId) external view returns (uint256[] memory) {
    return routes[workflowId].agentIds;
  }

  function getWorkflowConfig(
    bytes32 workflowId
  ) external view returns (ILlamaguardRiskOracleRouter.WorkflowConfig memory) {
    return _workflowConfigs[workflowId];
  }
}

contract MockAgent {}

contract TestLlamaGuardPTOracleActivation is LlamaGuardPTOracleActivationBase {
  address internal immutable _riskOracle;
  address internal immutable _emaOracle;
  address internal immutable _router;
  address internal immutable _discountRateAgent;
  address internal immutable _eModeAgent;
  bytes32 internal immutable _emaWorkflowId;
  bytes32 internal immutable _discountWorkflowId;
  bytes32 internal immutable _eModeWorkflowId;

  constructor(ActivationConfig memory config) {
    _riskOracle = config.riskOracle;
    _emaOracle = config.emaOracle;
    _router = config.router;
    _discountRateAgent = config.discountRateAgent;
    _eModeAgent = config.eModeAgent;
    _emaWorkflowId = config.emaWorkflowId;
    _discountWorkflowId = config.discountWorkflowId;
    _eModeWorkflowId = config.eModeWorkflowId;
  }

  function _getActivationConfig() internal view override returns (ActivationConfig memory) {
    return
      ActivationConfig({
        riskOracle: _riskOracle,
        emaOracle: _emaOracle,
        router: _router,
        discountRateAgent: _discountRateAgent,
        eModeAgent: _eModeAgent,
        emaWorkflowId: _emaWorkflowId,
        discountWorkflowId: _discountWorkflowId,
        eModeWorkflowId: _eModeWorkflowId
      });
  }
}

/**
 * @dev Test for AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811
 * command: FOUNDRY_PROFILE=test forge test --match-path=src/20260811_AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026/AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811.t.sol -vv
 */
contract AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811_Test is
  ProtocolV3TestBase
{
  uint256 internal constant FORK_BLOCK = 25_732_532;
  bytes32 internal constant EMA_WORKFLOW_ID = bytes32(uint256(0xE1));
  bytes32 internal constant DISCOUNT_WORKFLOW_ID = bytes32(uint256(0xD1));
  bytes32 internal constant EMODE_WORKFLOW_ID = bytes32(uint256(0xE2));

  AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811 internal proposal;
  TestLlamaGuardPTOracleActivation internal testPayload;
  MockRiskOracle internal riskOracle;
  MockEmaOracle internal emaOracle;
  MockRouter internal router;
  MockAgent internal discountAgent;
  MockAgent internal eModeAgent;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

    proposal = new AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811();
    riskOracle = new MockRiskOracle(AaveV3Ethereum.ACL_ADMIN);
    emaOracle = new MockEmaOracle(AaveV3Ethereum.ACL_ADMIN);
    router = new MockRouter(AaveV3Ethereum.ACL_ADMIN);
    discountAgent = new MockAgent();
    eModeAgent = new MockAgent();

    testPayload = new TestLlamaGuardPTOracleActivation(
      LlamaGuardPTOracleActivationBase.ActivationConfig({
        riskOracle: address(riskOracle),
        emaOracle: address(emaOracle),
        router: address(router),
        discountRateAgent: address(discountAgent),
        eModeAgent: address(eModeAgent),
        emaWorkflowId: EMA_WORKFLOW_ID,
        discountWorkflowId: DISCOUNT_WORKFLOW_ID,
        eModeWorkflowId: EMODE_WORKFLOW_ID
      })
    );
  }

  function test_oneAipActivation() public {
    IAgentHub hub = IAgentHub(MiscEthereum.AGENT_HUB);
    assertEq(hub.getAgentCount(), 5, 'fork no longer has the expected next IDs');
    assertFalse(riskOracle.isAuthorized(address(router)), 'router prematurely authorized');
    assertFalse(emaOracle.hasWriteAccess(address(router)), 'router prematurely has EMA writer');

    executePayload(vm, address(testPayload));

    assertEq(hub.getAgentCount(), 7, 'wrong final agent count');
    _assertDiscountAgent(hub);
    _assertEModeAgent(hub);
    _assertRangeConfiguration();

    assertTrue(riskOracle.isAuthorized(address(router)), 'router not authorized on RiskOracle');
    assertTrue(emaOracle.hasWriteAccess(address(router)), 'router lacks EMA writer role');
    assertEq(router.updater(), AaveV3Ethereum.ACL_ADMIN, 'wrong router updater');
    assertEq(router.guardian(), MiscEthereum.PROTOCOL_GUARDIAN, 'wrong router guardian');

    assertTrue(
      AaveV3Ethereum.ACL_MANAGER.isRiskAdmin(address(discountAgent)),
      'discount agent is not risk admin'
    );
    assertTrue(
      AaveV3Ethereum.ACL_MANAGER.isRiskAdmin(address(eModeAgent)),
      'eMode agent is not risk admin'
    );

    _assertRoute(
      EMA_WORKFLOW_ID,
      address(emaOracle),
      testPayload.EMA_PUBLISH_SELECTOR(),
      address(0),
      new uint256[](0),
      testPayload.EMA_WORKFLOW_NAME(),
      0
    );

    uint256[] memory discountAgentIds = new uint256[](1);
    discountAgentIds[0] = 5;
    _assertRoute(
      DISCOUNT_WORKFLOW_ID,
      address(riskOracle),
      testPayload.DISCOUNT_PUBLISH_SELECTOR(),
      MiscEthereum.AGENT_HUB,
      discountAgentIds,
      testPayload.DISCOUNT_WORKFLOW_NAME(),
      uint64(testPayload.DISCOUNT_MINIMUM_DELAY())
    );

    uint256[] memory eModeAgentIds = new uint256[](1);
    eModeAgentIds[0] = 6;
    _assertRoute(
      EMODE_WORKFLOW_ID,
      address(riskOracle),
      testPayload.EMODE_PUBLISH_SELECTOR(),
      MiscEthereum.AGENT_HUB,
      eModeAgentIds,
      testPayload.EMODE_WORKFLOW_NAME(),
      0
    );
  }

  function test_revertsIfAgentIdsAreNoLongerAvailable() public {
    vm.mockCall(
      MiscEthereum.AGENT_HUB,
      abi.encodeWithSelector(bytes4(keccak256('getAgentCount()'))),
      abi.encode(uint256(6))
    );

    uint40 payloadId = GovV3Helpers.readyPayload(vm, address(testPayload));
    // The Aave executor intentionally maps a failed inner delegatecall to protocol error `29`.
    vm.expectRevert(bytes('29'));
    GovV3Helpers.getPayloadsController(block.chainid).executePayload(payloadId);
    assertEq(IAgentHub(MiscEthereum.AGENT_HUB).getAgentCount(), 6, 'agent registration leaked');
  }

  function test_workflowNameConstantsMatchCreEncoding() public view {
    assertEq(
      testPayload.EMA_WORKFLOW_NAME(),
      _creWorkflowName(testPayload.EMA_WORKFLOW()),
      'wrong EMA workflow name'
    );
    assertEq(
      testPayload.DISCOUNT_WORKFLOW_NAME(),
      _creWorkflowName(testPayload.DISCOUNT_WORKFLOW()),
      'wrong discount workflow name'
    );
    assertEq(
      testPayload.EMODE_WORKFLOW_NAME(),
      _creWorkflowName(testPayload.EMODE_WORKFLOW()),
      'wrong eMode workflow name'
    );
  }

  function test_productionPayloadCannotExecuteWithPlaceholders() public {
    uint40 payloadId = GovV3Helpers.readyPayload(vm, address(proposal));
    vm.expectRevert(bytes('29'));
    GovV3Helpers.getPayloadsController(block.chainid).executePayload(payloadId);
  }

  /**
   * @dev Executes the generic test suite after all production values are inserted.
   * forge-config: default.isolate = true
   */
  function test_defaultProposalExecution() public {
    vm.skip(!_productionConfigurationComplete(), 'waiting for production deployment values');

    defaultTest(
      'AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811',
      AaveV3Ethereum.POOL,
      address(proposal)
    );
  }

  function test_reserveConfigurationsUnchanged() public {
    vm.skip(!_productionConfigurationComplete(), 'waiting for production deployment values');
    reserveConfigChangesTest(AaveV3Ethereum.POOL, address(proposal), new address[](0));
  }

  function test_productionAgentsTargetAaveCore() public {
    vm.skip(!_productionConfigurationComplete(), 'waiting for production deployment values');

    IAaveAgentDeployment productionDiscountAgent = IAaveAgentDeployment(
      proposal.DISCOUNT_RATE_AGENT()
    );
    IAaveAgentDeployment productionEModeAgent = IAaveAgentDeployment(proposal.EMODE_AGENT());

    assertEq(
      productionDiscountAgent.AGENT_HUB(),
      MiscEthereum.AGENT_HUB,
      'discount agent: wrong hub'
    );
    assertEq(
      productionDiscountAgent.RANGE_VALIDATION_MODULE(),
      MiscEthereum.RANGE_VALIDATION_MODULE,
      'discount agent: wrong range module'
    );
    assertEq(
      productionDiscountAgent.POOL(),
      address(AaveV3Ethereum.POOL),
      'discount agent: wrong pool'
    );
    assertEq(
      productionDiscountAgent.AAVE_ORACLE(),
      address(AaveV3Ethereum.ORACLE),
      'discount agent: wrong oracle'
    );

    assertEq(productionEModeAgent.AGENT_HUB(), MiscEthereum.AGENT_HUB, 'eMode agent: wrong hub');
    assertEq(
      productionEModeAgent.RANGE_VALIDATION_MODULE(),
      MiscEthereum.RANGE_VALIDATION_MODULE,
      'eMode agent: wrong range module'
    );
    assertEq(productionEModeAgent.POOL(), address(AaveV3Ethereum.POOL), 'eMode agent: wrong pool');
  }

  function _assertDiscountAgent(IAgentHub hub) internal view {
    uint256 agentId = 5;
    assertTrue(hub.isAgentEnabled(agentId), 'discount agent disabled');
    assertEq(hub.getAgentAddress(agentId), address(discountAgent), 'wrong discount agent');
    assertEq(hub.getRiskOracle(agentId), address(riskOracle), 'wrong discount RiskOracle');
    assertEq(
      hub.getUpdateType(agentId),
      testPayload.DISCOUNT_UPDATE_TYPE(),
      'wrong discount update type'
    );
    assertEq(hub.getAgentAdmin(agentId), AaveV3Ethereum.ACL_ADMIN, 'wrong discount admin');
    assertEq(
      hub.getExpirationPeriod(agentId),
      testPayload.DISCOUNT_EXPIRATION_PERIOD(),
      'wrong discount expiration'
    );
    assertEq(
      hub.getMinimumDelay(agentId),
      testPayload.DISCOUNT_MINIMUM_DELAY(),
      'wrong discount delay'
    );

    address[] memory markets = hub.getAllowedMarkets(agentId);
    assertEq(markets.length, 1, 'wrong discount market count');
    assertEq(
      markets[0],
      AaveV3EthereumAssets.PT_srUSDe_22OCT2026_UNDERLYING,
      'wrong discount market'
    );
  }

  function _assertEModeAgent(IAgentHub hub) internal view {
    uint256 agentId = 6;
    assertTrue(hub.isAgentEnabled(agentId), 'eMode agent disabled');
    assertEq(hub.getAgentAddress(agentId), address(eModeAgent), 'wrong eMode agent');
    assertEq(hub.getRiskOracle(agentId), address(riskOracle), 'wrong eMode RiskOracle');
    assertEq(
      hub.getUpdateType(agentId),
      testPayload.EMODE_UPDATE_TYPE(),
      'wrong eMode update type'
    );
    assertEq(hub.getAgentAdmin(agentId), AaveV3Ethereum.ACL_ADMIN, 'wrong eMode admin');
    assertEq(
      hub.getExpirationPeriod(agentId),
      testPayload.EMODE_EXPIRATION_PERIOD(),
      'wrong eMode expiration'
    );
    assertEq(hub.getMinimumDelay(agentId), testPayload.EMODE_MINIMUM_DELAY(), 'wrong eMode delay');
    assertEq(
      hub.getAgentContext(agentId),
      abi.encode(AaveV3Ethereum.CONFIG_ENGINE),
      'wrong eMode context'
    );

    address[] memory markets = hub.getAllowedMarkets(agentId);
    assertEq(markets.length, 2, 'wrong eMode market count');
    assertEq(
      markets[0],
      address(uint160(AaveV3EthereumEModes.sUSDe_PT_srUSDe_22OCT2026__USDC_USDT_USDe)),
      'wrong eMode market 0'
    );
    assertEq(
      markets[1],
      address(uint160(AaveV3EthereumEModes.sUSDe_PT_srUSDe_22OCT2026__USDe)),
      'wrong eMode market 1'
    );
  }

  function _assertRangeConfiguration() internal view {
    IRangeValidationModule rangeModule = IRangeValidationModule(
      MiscEthereum.RANGE_VALIDATION_MODULE
    );
    IRangeValidationModule.RangeConfig memory discountRange = rangeModule.getRangeConfigByMarket(
      MiscEthereum.AGENT_HUB,
      5,
      AaveV3EthereumAssets.PT_srUSDe_22OCT2026_UNDERLYING,
      testPayload.DISCOUNT_UPDATE_TYPE()
    );
    _assertRange(discountRange, testPayload.DISCOUNT_MAX_CHANGE(), 'discount');

    _assertRange(
      rangeModule.getDefaultRangeConfig(
        MiscEthereum.AGENT_HUB,
        6,
        testPayload.EMODE_LTV_UPDATE_TYPE()
      ),
      testPayload.EMODE_MAX_CHANGE_BPS(),
      'eMode LTV'
    );
    _assertRange(
      rangeModule.getDefaultRangeConfig(
        MiscEthereum.AGENT_HUB,
        6,
        testPayload.EMODE_LT_UPDATE_TYPE()
      ),
      testPayload.EMODE_MAX_CHANGE_BPS(),
      'eMode LT'
    );
    _assertRange(
      rangeModule.getDefaultRangeConfig(
        MiscEthereum.AGENT_HUB,
        6,
        testPayload.EMODE_LB_UPDATE_TYPE()
      ),
      testPayload.EMODE_MAX_CHANGE_BPS(),
      'eMode LB'
    );
  }

  function _assertRange(
    IRangeValidationModule.RangeConfig memory range,
    uint120 expected,
    string memory label
  ) internal pure {
    assertEq(range.maxIncrease, expected, string.concat(label, ': wrong max increase'));
    assertEq(range.maxDecrease, expected, string.concat(label, ': wrong max decrease'));
    assertFalse(range.isIncreaseRelative, string.concat(label, ': increase must be absolute'));
    assertFalse(range.isDecreaseRelative, string.concat(label, ': decrease must be absolute'));
  }

  function _assertRoute(
    bytes32 workflowId,
    address expectedRiskOracle,
    bytes4 expectedSelector,
    address expectedAgentHub,
    uint256[] memory expectedAgentIds,
    bytes10 expectedWorkflowName,
    uint64 expectedMinimumDelay
  ) internal view {
    _assertRouteAgentIds(workflowId, expectedAgentIds);
    _assertWorkflowConfig(workflowId, expectedWorkflowName);

    (
      address routeRiskOracle,
      bytes4 publishSelector,
      address agentHub,
      bool enabled,
      uint64 minDelaySeconds,
      uint64 maxStepBps
    ) = router.routes(workflowId);
    assertEq(routeRiskOracle, expectedRiskOracle, 'wrong route RiskOracle');
    assertEq(publishSelector, expectedSelector, 'wrong route selector');
    assertEq(agentHub, expectedAgentHub, 'wrong route AgentHub');
    assertTrue(enabled, 'route disabled');
    assertEq(minDelaySeconds, expectedMinimumDelay, 'wrong route minimum delay');
    assertEq(maxStepBps, 0, 'Router max-step must be disabled');
  }

  function _assertRouteAgentIds(
    bytes32 workflowId,
    uint256[] memory expectedAgentIds
  ) internal view {
    uint256[] memory agentIds = router.getAgentIds(workflowId);
    assertEq(agentIds, expectedAgentIds, 'wrong route agent IDs');
  }

  function _assertWorkflowConfig(bytes32 workflowId, bytes10 expectedWorkflowName) internal view {
    ILlamaguardRiskOracleRouter.WorkflowConfig memory workflowConfig = router.getWorkflowConfig(
      workflowId
    );
    assertEq(
      workflowConfig.expectedForwarder,
      testPayload.CRE_FORWARDER(),
      'wrong workflow forwarder'
    );
    assertEq(
      workflowConfig.expectedAuthor,
      testPayload.CRE_WORKFLOW_AUTHOR(),
      'wrong workflow author'
    );
    assertEq(workflowConfig.expectedWorkflowName, expectedWorkflowName, 'wrong workflow name');
    assertTrue(workflowConfig.isActive, 'workflow inactive');
  }

  function _creWorkflowName(string memory workflowName) internal pure returns (bytes10) {
    bytes32 digest = sha256(bytes(workflowName));
    bytes memory hexChars = '0123456789abcdef';
    bytes memory result = new bytes(10);
    for (uint256 i = 0; i < 5; i++) {
      uint8 value = uint8(digest[i]);
      result[i * 2] = hexChars[value >> 4];
      result[i * 2 + 1] = hexChars[value & 0x0f];
    }
    return bytes10(result);
  }

  function _productionConfigurationComplete() internal view returns (bool) {
    return
      proposal.LLAMARISK_RISK_ORACLE().code.length != 0 &&
      proposal.LLAMAGUARD_EMA_ORACLE().code.length != 0 &&
      proposal.LLAMAGUARD_ROUTER().code.length != 0 &&
      proposal.DISCOUNT_RATE_AGENT().code.length != 0 &&
      proposal.EMODE_AGENT().code.length != 0 &&
      proposal.EMA_WORKFLOW_ID() != bytes32(0) &&
      proposal.DISCOUNT_WORKFLOW_ID() != bytes32(0) &&
      proposal.EMODE_WORKFLOW_ID() != bytes32(0);
  }
}
