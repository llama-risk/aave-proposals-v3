// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILlamaguardRiskOracleRouter {
  struct WorkflowConfig {
    address expectedForwarder;
    address expectedAuthor;
    bytes10 expectedWorkflowName;
    bool isActive;
  }

  function owner() external view returns (address);

  function updater() external view returns (address);

  function guardian() external view returns (address);

  function setUpdater(address newUpdater) external;

  function setGuardian(address newGuardian) external;

  function addRoute(
    bytes32 workflowId,
    address forwarder,
    address author,
    bytes10 workflowName,
    address riskOracle,
    bytes4 publishSelector,
    address agentHub,
    uint256[] calldata agentIds
  ) external;

  function setRouteThrottle(bytes32 workflowId, uint64 minDelaySeconds, uint64 maxStepBps) external;

  function getAgentIds(bytes32 workflowId) external view returns (uint256[] memory);

  function getWorkflowConfig(bytes32 workflowId) external view returns (WorkflowConfig memory);

  function routes(
    bytes32 workflowId
  )
    external
    view
    returns (
      address riskOracle,
      bytes4 publishSelector,
      address agentHub,
      bool enabled,
      uint64 minDelaySeconds,
      uint64 maxStepBps
    );
}
