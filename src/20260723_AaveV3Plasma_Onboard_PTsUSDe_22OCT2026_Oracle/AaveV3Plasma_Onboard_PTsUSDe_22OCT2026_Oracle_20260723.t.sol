// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Plasma, AaveV3PlasmaAssets, AaveV3PlasmaEModes} from 'aave-address-book/AaveV3Plasma.sol';
import {MiscPlasma} from 'aave-address-book/MiscPlasma.sol';

import 'forge-std/Test.sol';
import {ProtocolV3TestBase, ReserveConfig} from 'aave-helpers/src/ProtocolV3TestBase.sol';
import {AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723} from './AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723.sol';
import {IAgentHub} from '../interfaces/chaos-agents/IAgentHub.sol';

/**
 * @dev Test for AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723
 * command: FOUNDRY_PROFILE=test forge test --match-path=src/20260723_AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle/AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723.t.sol -vv
 */
contract AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723_Test is ProtocolV3TestBase {
  AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723 internal proposal;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('plasma'), 27898416);
    proposal = new AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723();
  }

  /**
   * @dev executes the generic test suite including e2e and config snapshots
   * forge-config: default.isolate = true
   */
  function test_defaultProposalExecution() public {
    defaultTest(
      'AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723',
      AaveV3Plasma.POOL,
      address(proposal)
    );
  }

  /**
   * @dev checks whether reserve configurations changed or stayed unchanged as expected
   */
  function test_reserveConfigChanges() public {
    address[] memory updatedAssets = new address[](0);

    reserveConfigChangesTest(AaveV3Plasma.POOL, address(proposal), updatedAssets);
  }

  function test_agentsRegisteredAndRiskAdminGranted() public {
    IAgentHub hub = IAgentHub(MiscPlasma.AGENT_HUB);
    uint256 countBefore = hub.getAgentCount();

    executePayload(vm, address(proposal));

    assertEq(hub.getAgentCount(), countBefore + 2, 'agent count did not increase by 2');

    uint256 discountAgentId = countBefore;
    uint256 eModeAgentId = countBefore + 1;

    // discount-rate agent
    assertTrue(hub.isAgentEnabled(discountAgentId), 'discount agent not enabled');
    assertEq(
      hub.getAgentAddress(discountAgentId),
      proposal.DISCOUNT_RATE_AGENT(),
      'wrong discount agent address'
    );
    assertEq(
      hub.getRiskOracle(discountAgentId),
      proposal.LLAMARISK_RISK_ORACLE(),
      'wrong discount agent risk oracle'
    );
    assertEq(
      hub.getUpdateType(discountAgentId),
      proposal.DISCOUNT_UPDATE_TYPE(),
      'wrong discount agent update type'
    );
    assertEq(
      hub.getAgentAdmin(discountAgentId),
      proposal.AGENT_ADMIN(),
      'wrong discount agent admin'
    );
    address[] memory discountMarkets = hub.getAllowedMarkets(discountAgentId);
    assertEq(discountMarkets.length, 1, 'wrong discount agent allowed markets length');
    assertEq(
      discountMarkets[0],
      AaveV3PlasmaAssets.PT_sUSDE_22OCT2026_UNDERLYING,
      'wrong discount agent allowed market'
    );
    assertTrue(
      AaveV3Plasma.ACL_MANAGER.isRiskAdmin(proposal.DISCOUNT_RATE_AGENT()),
      'discount agent not risk admin'
    );

    // eMode agent
    assertTrue(hub.isAgentEnabled(eModeAgentId), 'eMode agent not enabled');
    assertEq(
      hub.getAgentAddress(eModeAgentId),
      proposal.EMODE_AGENT(),
      'wrong eMode agent address'
    );
    assertEq(
      hub.getRiskOracle(eModeAgentId),
      proposal.LLAMARISK_RISK_ORACLE(),
      'wrong eMode agent risk oracle'
    );
    assertEq(
      hub.getUpdateType(eModeAgentId),
      proposal.EMODE_UPDATE_TYPE(),
      'wrong eMode agent update type'
    );
    assertEq(hub.getAgentAdmin(eModeAgentId), proposal.AGENT_ADMIN(), 'wrong eMode agent admin');
    address[] memory eModeMarkets = hub.getAllowedMarkets(eModeAgentId);
    assertEq(eModeMarkets.length, 2, 'wrong eMode agent allowed markets length');
    assertEq(
      eModeMarkets[0],
      address(uint160(AaveV3PlasmaEModes.sUSDe_PT_sUSDE_22OCT2026__USDT0_USDe_GHO)),
      'wrong eMode agent allowed market 0'
    );
    assertEq(
      eModeMarkets[1],
      address(uint160(AaveV3PlasmaEModes.sUSDe_PT_sUSDE_22OCT2026__USDe)),
      'wrong eMode agent allowed market 1'
    );
    assertTrue(
      AaveV3Plasma.ACL_MANAGER.isRiskAdmin(proposal.EMODE_AGENT()),
      'eMode agent not risk admin'
    );
  }
}
