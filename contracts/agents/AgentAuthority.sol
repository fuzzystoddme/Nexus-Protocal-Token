// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GovernanceRoles.sol";

contract AgentAuthority {
    GovernanceRoles public roles;

    enum AgentType {
        NONE,
        LIQUIDITY_GUARDIAN,
        COMPLIANCE_SENTINEL,
        SETTLEMENT_ROUTER,
        RWA_CUSTODIAN,
        TREASURY_OPTIMIZER,
        GOVERNANCE_AUDITOR,
        AI_ANALYST,
        NETWORK_MAINTAINER
    }

    struct JobDescription {
        AgentType agentType;
        string name;
        string scope;
        string permissions;
        string constraints;
        string reporting;
        bool active;
    }

    mapping(address => JobDescription) public agents;

    event AgentRegistered(address indexed agent, AgentType agentType, string name);
    event AgentUpdated(address indexed agent);
    event AgentDeactivated(address indexed agent);

    constructor(address rolesAddress) {
        roles = GovernanceRoles(rolesAddress);
    }

    function registerAgent(
        address agent,
        AgentType agentType,
        string calldata name,
        string calldata scope,
        string calldata permissions,
        string calldata constraints,
        string calldata reporting
    ) external {
        require(
            roles.roles(msg.sender) == GovernanceRoles.Role.FOUNDER ||
            roles.roles(msg.sender) == GovernanceRoles.Role.OPERATOR,
            "Not authorized"
        );

        agents[agent] = JobDescription(
            agentType,
            name,
            scope,
            permissions,
            constraints,
            reporting,
            true
        );

        emit AgentRegistered(agent, agentType, name);
    }

    function updateAgent(
        address agent,
        string calldata scope,
        string calldata permissions,
        string calldata constraints,
        string calldata reporting
    ) external {
        require(
            roles.roles(msg.sender) == GovernanceRoles.Role.FOUNDER ||
            roles.roles(msg.sender) == GovernanceRoles.Role.OPERATOR,
            "Not authorized"
        );

        JobDescription storage jd = agents[agent];
        jd.scope = scope;
        jd.permissions = permissions;
        jd.constraints = constraints;
        jd.reporting = reporting;

        emit AgentUpdated(agent);
    }

    function deactivateAgent(address agent) external {
        require(
            roles.roles(msg.sender) == GovernanceRoles.Role.FOUNDER ||
            roles.roles(msg.sender) == GovernanceRoles.Role.OPERATOR,
            "Not authorized"
        );

        agents[agent].active = false;
        emit AgentDeactivated(agent);
    }

    function isActive(address agent) external view returns (bool) {
        return agents[agent].active;
    }
}
