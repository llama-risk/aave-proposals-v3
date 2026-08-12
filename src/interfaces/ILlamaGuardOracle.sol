// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILlamaGuardOracle {
  struct UpdateInput {
    string referenceId;
    bytes newValue;
    string updateType;
    bytes additionalData;
    uint256 deadline;
  }

  function updateLatestRiskRoundData(UpdateInput calldata input) external;

  function WRITER_ROLE() external view returns (bytes32);

  function hasRole(bytes32 role, address account) external view returns (bool);

  function grantRole(bytes32 role, address account) external;

  function hasWriteAccess(address account) external view returns (bool);
}
