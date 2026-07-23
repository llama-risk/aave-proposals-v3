// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Plasma} from 'aave-address-book/AaveV3Plasma.sol';

import 'forge-std/Test.sol';
import {ProtocolV3TestBase, ReserveConfig} from 'aave-helpers/src/ProtocolV3TestBase.sol';
import {AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723} from './AaveV3Plasma_Onboard_PTsUSDe_22OCT2026_Oracle_20260723.sol';

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
}
