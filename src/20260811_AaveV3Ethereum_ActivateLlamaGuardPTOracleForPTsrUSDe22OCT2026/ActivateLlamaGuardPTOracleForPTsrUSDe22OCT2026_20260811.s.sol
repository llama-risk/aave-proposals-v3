// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GovV3Helpers, IPayloadsControllerCore, PayloadsControllerUtils} from 'aave-helpers/src/GovV3Helpers.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';

import {EthereumScript} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811} from './AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811.sol';

/**
 * @dev Deploy Ethereum
 * deploy-command: make deploy-ledger contract=src/20260811_AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026/ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811.s.sol:DeployEthereum chain=mainnet
 * verify-command: FOUNDRY_PROFILE=deploy npx catapulta-verify -b broadcast/ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811.s.sol/1/run-latest.json
 */
contract DeployEthereum is EthereumScript {
  function run() external broadcast {
    address payload = GovV3Helpers.deployDeterministic(
      type(AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811).creationCode
    );

    IPayloadsControllerCore.ExecutionAction[]
      memory actions = new IPayloadsControllerCore.ExecutionAction[](1);
    actions[0] = GovV3Helpers.buildAction(payload);

    GovV3Helpers.createPayload(actions);
  }
}

/**
 * @dev Create Proposal
 * command: make deploy-ledger contract=src/20260811_AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026/ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811.s.sol:CreateProposal chain=mainnet
 */
contract CreateProposal is EthereumScript {
  function run() external {
    PayloadsControllerUtils.Payload[] memory payloads = new PayloadsControllerUtils.Payload[](1);

    IPayloadsControllerCore.ExecutionAction[]
      memory actionsEthereum = new IPayloadsControllerCore.ExecutionAction[](1);
    actionsEthereum[0] = GovV3Helpers.buildAction(
      type(AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026_20260811).creationCode
    );
    payloads[0] = GovV3Helpers.buildMainnetPayload(vm, actionsEthereum);

    vm.startBroadcast();
    GovV3Helpers.createProposal(
      vm,
      payloads,
      GovernanceV3Ethereum.VOTING_PORTAL_ETH_AVAX,
      GovV3Helpers.ipfsHashFile(
        vm,
        'src/20260811_AaveV3Ethereum_ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026/ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026.md'
      )
    );
  }
}
